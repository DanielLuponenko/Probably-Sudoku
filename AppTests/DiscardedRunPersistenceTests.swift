import XCTest
import Foundation
import ProbablySudokuEngine
@testable import ProbablySudoku

/// Temporary local files plus an in-memory copy of the production envelope.
/// No test calls RunStore's global facade or the real iCloud transport.
final class DiscardedRunPersistenceTests: XCTestCase {
    func testFailedRetirementRollbackRemembersTheArchivedAlternative() throws {
        for replaces in [false, true] {
            let cloud = RunCloudProbe()
            var storage = try makeStorage(cloud)
            let local = Game(seed: "rollback-authority-\(replaces)")
            let remote = Game(seed: "rollback-alternative-\(replaces)")
            XCTAssertTrue(storage.save(local))
            try cloud.deliverLegacy(remote)
            let oldLocal = try Data(contentsOf: storage.directory.appendingPathComponent("run.json"))
            if replaces {
                let write = storage.write
                storage.write = { data, url in
                    if url.lastPathComponent == "run.json" { throw CocoaError(.fileWriteNoPermission) }
                    try write(data, url)
                }
                XCTAssertFalse(storage.replace(expected: local, with: Game(seed: "unsaved-replacement")))
            } else {
                storage.remove = { _ in throw CocoaError(.fileWriteNoPermission) }
                XCTAssertFalse(storage.clearRun())
            }
            XCTAssertEqual(try Data(contentsOf: storage.directory.appendingPathComponent("run.json")), oldLocal)
            XCTAssertNil(storage.loadRemoteRun(), "Rollback must not unretire the archived other attempt")
            cloud.envelope = nil
            let reopened = storageFor(directory: storage.directory, cloud: cloud)
            XCTAssertTrue(reopened.clearRun())
            try cloud.deliverLegacy(remote, modifiedAt: 9_999_999_999)
            XCTAssertNil(reopened.displayedRun())
            XCTAssertNil(reopened.resumeRun())
        }
    }

    func testUnreadableCloudEnvelopeIsNotAnEmptySlotForAFirstStart() throws {
        let validPayload = try Game(seed: "future-cloud-game").encoded()
        let envelopes = [Data("broken envelope bytes".utf8), try JSONSerialization.data(withJSONObject: [
            "schema": 2, "modifiedAt": 42, "payload": validPayload.base64EncodedString()
        ])]
        for envelope in envelopes {
            let cloud = RunCloudProbe()
            let storage = try makeStorage(cloud)
            cloud.envelope = envelope
            XCTAssertTrue(cloud.snapshot.isUnreadable)
            XCTAssertEqual(cloud.snapshot.envelopeData, envelope)
            XCTAssertNil(storage.displayedRun())
            XCTAssertNil(storage.resumeRun())
            XCTAssertFalse(storage.save(Game(seed: "must-not-overwrite-unreadable-cloud")))
            XCTAssertFalse(storage.clearRun())
            XCTAssertFalse(storage.replace(expected: Game(seed: "future-cloud-game"),
                                           with: Game(seed: "replacement")))
            XCTAssertNil(storage.loadRun())
            XCTAssertEqual(cloud.envelope, envelope)
            XCTAssertEqual(cloud.publishes, 0)
        }
    }

    func testLocalCheckpointArchivesUnreadableCloudEnvelopeBeforePublication() throws {
        let cloud = RunCloudProbe()
        let storage = try makeStorage(cloud)
        let local = Game(seed: "valid-local-next-to-future-cloud")
        XCTAssertTrue(storage.save(local))
        let unreadable = Data("unrecognized cloud metadata to preserve".utf8)
        cloud.envelope = unreadable
        let checkpoint = try advancedCheckpoint(local)
        XCTAssertTrue(storage.save(checkpoint))
        XCTAssertEqual(try archivedEnvelopes(storage), [unreadable])
        XCTAssertNil(RunStore.conflict(local: try XCTUnwrap(storage.loadRun()), remote: checkpoint))
        XCTAssertNil(RunStore.conflict(local: try XCTUnwrap(RunStore.game(from: cloud.snapshot.data)), remote: checkpoint))
        XCTAssertEqual(cloud.publishes, 2)
    }

    func testValidLegacyFailedLocalSaveAllowsANewAttemptWithoutPromotingAnotherRemoteBook() throws {
        let cloud = RunCloudProbe()
        let storage = try makeStorage(cloud)
        var terminal = Game(seed: "historical-failed-book").run
        terminal.outcome = .failed
        let failed = Game(run: terminal)
        let failedBytes = try failed.encoded()
        try failedBytes.write(to: storage.directory.appendingPathComponent("run.json"), options: .atomic)
        let remote = Game(seed: "unrelated-remote-beside-failure")
        try cloud.deliverLegacy(remote)
        XCTAssertNil(storage.displayedRun())
        XCTAssertNil(storage.resumeRun())

        let fresh = Game(seed: "explicit-fresh-after-loss")
        XCTAssertTrue(storage.save(fresh))
        XCTAssertEqual(storage.resumeRun()?.run.seed, fresh.run.seed)
        XCTAssertTrue(cloud.snapshot.discardedRuns.contains(RunStore.DiscardedRunIdentity(failed)))
        XCTAssertTrue(cloud.snapshot.discardedRuns.contains(RunStore.DiscardedRunIdentity(remote)))
        try cloud.deliverLegacy(remote)
        XCTAssertEqual(storage.displayedRun()?.run.seed, fresh.run.seed)
        XCTAssertNil(storage.loadRemoteRun())
    }

    func testOlderCheckpointOfSameAttemptIsArchivedWithoutCreatingAnotherPlayableBook() throws {
        let cloud = RunCloudProbe()
        let storage = try makeStorage(cloud)
        let earlier = Game(seed: "one-book-two-checkpoints")
        XCTAssertTrue(storage.save(earlier))
        let current = try advancedCheckpoint(earlier)
        XCTAssertTrue(storage.save(current))
        try cloud.deliverLegacy(earlier, modifiedAt: 9_999_999_999)
        let originalEnvelope = try XCTUnwrap(cloud.envelope)
        let localBytes = try Data(contentsOf: storage.directory.appendingPathComponent("run.json"))

        for _ in 0..<3 {
            XCTAssertNil(storage.conflict())
            XCTAssertNil(RunStore.conflict(local: try XCTUnwrap(storage.displayedRun()), remote: current))
            XCTAssertNil(RunStore.conflict(local: try XCTUnwrap(storage.resumeRun()), remote: current))
        }

        XCTAssertEqual(try Data(contentsOf: storage.directory.appendingPathComponent("run.json")), localBytes)
        XCTAssertEqual(try archivedEnvelopes(storage), [originalEnvelope], "The same received bytes are retained once")
        XCTAssertNotNil(storage.loadRemoteRun(), "An older checkpoint must not tombstone the active attempt")
        XCTAssertEqual(cloud.publishes, 2, "Inspecting/resuming local authority does not rewrite cloud history")
    }

    func testEvenFurtherAdvancedRemoteCheckpointNeverReplacesValidLocalState() throws {
        let cloud = RunCloudProbe()
        let storage = try makeStorage(cloud)
        let local = Game(seed: "local-remains-authoritative")
        XCTAssertTrue(storage.save(local))
        let remote = try advancedCheckpoint(local, turns: 5)
        try cloud.deliverLegacy(remote, modifiedAt: 9_999_999_999)
        let localBytes = try Data(contentsOf: storage.directory.appendingPathComponent("run.json"))
        XCTAssertNil(RunStore.conflict(local: try XCTUnwrap(storage.resumeRun()), remote: local))
        XCTAssertEqual(try Data(contentsOf: storage.directory.appendingPathComponent("run.json")), localBytes)
        XCTAssertEqual(try archivedEnvelopes(storage), [try XCTUnwrap(cloud.envelope)])
    }

    func testPreviouslyObservedAlternativeCannotReappearAfterAuthorityIsAbandoned() throws {
        let cloud = RunCloudProbe()
        let storage = try makeStorage(cloud)
        let local = Game(seed: "sole-local")
        let ignored = Game(seed: "previous-other-device-attempt", book: .smallVictories)
        XCTAssertTrue(storage.save(local))
        try cloud.deliverLegacy(ignored)
        XCTAssertEqual(storage.displayedRun()?.run.seed, local.run.seed)
        let ignoredEnvelope = try XCTUnwrap(cloud.envelope)
        try cloud.deliverLegacy(local)
        XCTAssertTrue(storage.clearRun())
        try cloud.deliverLegacy(ignored, modifiedAt: 9_999_999_999)
        let reopened = storageFor(directory: storage.directory, cloud: cloud)
        XCTAssertNil(reopened.displayedRun())
        XCTAssertNil(reopened.resumeRun())
        XCTAssertTrue(try archivedEnvelopes(storage).contains(ignoredEnvelope))
    }

    func testImplicitStartCannotReplaceLocalOrLateArrivingRemoteAuthority() throws {
        for hasLocal in [true, false] {
            let cloud = RunCloudProbe()
            let storage = try makeStorage(cloud)
            let active = Game(seed: "already-active-\(hasLocal)")
            if hasLocal { XCTAssertTrue(storage.save(active)) }
            else { try cloud.deliverLegacy(active) }
            let envelope = cloud.envelope
            XCTAssertFalse(storage.save(Game(seed: "unconfirmed-other-book", book: .smallVictories)))
            XCTAssertEqual(storage.displayedRun()?.run.seed, active.run.seed)
            XCTAssertEqual(storage.loadRun()?.run.seed, hasLocal ? active.run.seed : nil)
            XCTAssertEqual(cloud.envelope, envelope)
            XCTAssertEqual(cloud.publishes, hasLocal ? 1 : 0)
        }
    }

    func testUnreadableOrCorruptLocalBytesNeverBecomeAnEmptySlotForRemoteAdoption() throws {
        for permissionFailure in [false, true] {
            let cloud = RunCloudProbe()
            var storage = try makeStorage(cloud)
            let local = Game(seed: "protect-local-bytes-\(permissionFailure)")
            XCTAssertTrue(storage.save(local))
            let url = storage.directory.appendingPathComponent("run.json")
            let protectedBytes = permissionFailure ? try Data(contentsOf: url) : Data("unrecognized historical save".utf8)
            try protectedBytes.write(to: url, options: .atomic)
            try cloud.deliverLegacy(Game(seed: "do-not-adopt-over-unreadable-local"))
            if permissionFailure {
                let read = storage.read
                storage.read = { url in
                    if url.lastPathComponent == "run.json" { throw CocoaError(.fileReadNoPermission) }
                    return try read(url)
                }
            }
            XCTAssertNil(storage.displayedRun())
            XCTAssertNil(storage.resumeRun())
            XCTAssertFalse(storage.save(Game(seed: "new-start")))
            XCTAssertFalse(storage.clearRun())
            XCTAssertFalse(storage.replace(expected: local, with: Game(seed: "new-replacement")))
            XCTAssertEqual(try Data(contentsOf: url), protectedBytes)
        }
    }

    func testBackupFailureBlocksMutationWithoutHidingValidLocalContinue() throws {
        let cloud = RunCloudProbe()
        var storage = try makeStorage(cloud)
        let local = Game(seed: "backup-must-be-durable")
        XCTAssertTrue(storage.save(local))
        try cloud.deliverLegacy(Game(seed: "divergent-cloud-evidence"))
        let oldCloud = cloud.envelope
        let url = storage.directory.appendingPathComponent("run.json")
        let oldLocal = try Data(contentsOf: url)
        let write = storage.write
        storage.write = { data, url in
            if url.path.contains("/run-backups/") { throw CocoaError(.fileWriteNoPermission) }
            try write(data, url)
        }
        let checkpoint = try advancedCheckpoint(local)
        XCTAssertEqual(storage.resumeRun()?.run.seed, local.run.seed)
        XCTAssertFalse(storage.save(checkpoint))
        XCTAssertFalse(storage.clearRun())
        XCTAssertFalse(storage.replace(expected: local, with: Game(seed: "not-yet-replaced")))
        XCTAssertEqual(try Data(contentsOf: url), oldLocal)
        XCTAssertEqual(cloud.envelope, oldCloud)
        XCTAssertEqual(cloud.publishes, 1)
    }

    func testRemoteOnlyResumeRejectsAChangedSnapshotBetweenReadAndDurableAdoption() throws {
        let cloud = RunCloudProbe()
        var storage = try makeStorage(cloud)
        let original = Game(seed: "remote-before-continue")
        let newer = try advancedCheckpoint(original)
        try cloud.deliverLegacy(original)
        let originalSnapshot = cloud.snapshot
        try cloud.deliverLegacy(newer)
        let newerSnapshot = cloud.snapshot
        var reads = 0
        storage.remoteSnapshot = {
            reads += 1
            return reads == 1 ? originalSnapshot : newerSnapshot
        }
        XCTAssertNil(storage.resumeRun())
        XCTAssertNil(storage.loadRun())
        XCTAssertEqual(cloud.publishes, 0)
        XCTAssertEqual(RunStore.game(from: cloud.snapshot.data)?.run.slot, newer.run.slot)
    }

    func testFailedAndCompletedAuthorityRetirementDoNotRevealArchivedRemoteAttempts() throws {
        for completes in [false, true] {
            let cloud = RunCloudProbe()
            let storage = try makeStorage(cloud)
            let original = Game(seed: "terminal-authority-\(completes)")
            let remote = Game(seed: "ignored-terminal-alternative-\(completes)")
            XCTAssertTrue(storage.save(original))
            try cloud.deliverLegacy(remote)
            var terminal = original.run
            terminal.outcome = completes ? .bookCompleted : .failed
            XCTAssertTrue(storage.save(Game(run: terminal)))
            if completes {
                XCTAssertEqual(storage.displayedRun()?.run.outcome, .bookCompleted)
                XCTAssertTrue(storage.clearRun())
            }
            try cloud.deliverLegacy(remote)
            XCTAssertNil(storageFor(directory: storage.directory, cloud: cloud).displayedRun())
        }
    }

    func testCloudSnapshotRetainsExactEnvelopeAndTimestampOnlyAsEvidence() throws {
        let cloud = RunCloudProbe()
        try cloud.deliverLegacy(Game(seed: "metadata-evidence"), modifiedAt: 1234)
        let envelope = try XCTUnwrap(cloud.envelope)
        let snapshot = CloudSync.runSnapshot(fromEnvelope: envelope)
        XCTAssertEqual(snapshot.modifiedAt, Date(timeIntervalSinceReferenceDate: 1234))
        XCTAssertEqual(snapshot.envelopeData, envelope)
        XCTAssertEqual(RunStore.game(from: snapshot.data)?.run.seed, "metadata-evidence")
    }

    func testAbandonSurvivesRelaunchAndRejectsLaterLegacyCloudSnapshotsOfTheSameAttempt() throws {
        let cloud = RunCloudProbe()
        let storage = try makeStorage(cloud)
        let original = Game(seed: "discarded-attempt")
        XCTAssertTrue(storage.save(original))
        XCTAssertTrue(storage.clearRun())
        XCTAssertNil(storage.loadRun())
        XCTAssertNil(CloudSync.runData(fromEnvelope: cloud.envelope))
        XCTAssertEqual(cloud.snapshot.discardedRuns, [RunStore.DiscardedRunIdentity(original)])

        let stale = try advancedCheckpoint(original)
        try cloud.deliverLegacy(stale, modifiedAt: 9_999_999_999)
        let reopened = storageFor(directory: storage.directory, cloud: cloud)
        XCTAssertNil(reopened.loadRemoteRun())
        XCTAssertNil(reopened.displayedRun())
        XCTAssertNil(reopened.resumeRun())
        XCTAssertNil(reopened.conflict())
        XCTAssertEqual(cloud.publishes, 2, "Rejecting stale cloud state is not a new run save")
    }

    func testDiscardingLocalBookArchivesAndRetiresAnUnrelatedRemoteBook() throws {
        let cloud = RunCloudProbe()
        let storage = try makeStorage(cloud)
        let local = Game(seed: "local-to-abandon")
        let remote = Game(seed: "other-device", book: .smallVictories)
        XCTAssertTrue(storage.save(local))
        try cloud.deliverLegacy(remote)
        let remoteEnvelope = cloud.envelope

        XCTAssertTrue(storage.clearRun())
        XCTAssertNil(storage.loadRun())
        XCTAssertNil(cloud.snapshot.data)
        XCTAssertNil(storage.displayedRun())
        XCTAssertNil(storage.resumeRun())
        XCTAssertTrue(try archivedEnvelopes(storage).contains(try XCTUnwrap(remoteEnvelope)))
        XCTAssertTrue(cloud.snapshot.discardedRuns.contains(RunStore.DiscardedRunIdentity(local)))
        XCTAssertTrue(cloud.snapshot.discardedRuns.contains(RunStore.DiscardedRunIdentity(remote)))
        try cloud.deliverLegacy(remote, modifiedAt: 9_999_999_999)
        XCTAssertNil(storageFor(directory: storage.directory, cloud: cloud).displayedRun())
    }

    func testIdentityIncludesBookAndObstacleAndAllowsAnExplicitLocalSameSeedRestart() throws {
        let cloud = RunCloudProbe()
        let storage = try makeStorage(cloud)
        let old = Game(seed: "named-seed")
        XCTAssertTrue(storage.save(old))
        XCTAssertTrue(storage.clearRun())
        for other in [Game(seed: "named-seed", book: .smallVictories),
                      Game(seed: "named-seed", obstacle: .shortHanded)] {
            try cloud.deliverLegacy(other)
            XCTAssertNotNil(storage.loadRemoteRun(), "Book and obstacle are part of the discarded identity")
        }
        try cloud.deliverLegacy(old)
        XCTAssertNil(storage.loadRemoteRun())
        XCTAssertTrue(storage.save(Game(seed: "named-seed")))
        XCTAssertEqual(storage.loadRun()?.run.seed, "named-seed")
        XCTAssertEqual(storage.resumeRun()?.run.seed, "named-seed")
        XCTAssertNil(storage.loadRemoteRun(), "An explicit local restart cannot authenticate an ambiguous old cloud attempt")
    }

    func testRemoteDeletionMetadataIsRememberedBeforeAnOlderEnvelopeArrives() throws {
        let cloud = RunCloudProbe()
        let storage = try makeStorage(cloud)
        let old = Game(seed: "other-device-abandoned")
        cloud.envelope = try CloudSync.encodedRunEnvelope(.init(data: nil,
            discardedRuns: [RunStore.DiscardedRunIdentity(old)]), modifiedAt: Date(timeIntervalSince1970: 1))
        XCTAssertNil(storage.loadRemoteRun())
        try cloud.deliverLegacy(old, modifiedAt: 9_999_999_999)
        XCTAssertNil(storageFor(directory: storage.directory, cloud: cloud).loadRemoteRun())
        XCTAssertEqual(cloud.publishes, 0)
    }

    func testWriteFailureDoesNotPublishOrReplaceThePreviousLocalRun() throws {
        let cloud = RunCloudProbe()
        var storage = try makeStorage(cloud)
        let old = Game(seed: "durable-before-write-error")
        XCTAssertTrue(storage.save(old))
        let originalBytes = try Data(contentsOf: storage.directory.appendingPathComponent("run.json"))
        let originalWrite = storage.write
        storage.write = { data, url in
            if url.lastPathComponent == "run.json" { throw CocoaError(.fileWriteNoPermission) }
            try originalWrite(data, url)
        }
        let checkpoint = try advancedCheckpoint(old)
        XCTAssertFalse(storage.save(checkpoint))
        XCTAssertEqual(storage.loadRun()?.run.seed, old.run.seed)
        XCTAssertEqual(try Data(contentsOf: storage.directory.appendingPathComponent("run.json")), originalBytes)
        XCTAssertEqual(try XCTUnwrap(RunStore.game(from: cloud.snapshot.data)).run.seed, old.run.seed)
        XCTAssertEqual(cloud.publishes, 1)
    }

    func testRemoveFailureKeepsTheLocalRunAndDoesNotPublishDeletion() throws {
        let cloud = RunCloudProbe()
        var storage = try makeStorage(cloud)
        let old = Game(seed: "durable-before-remove-error")
        XCTAssertTrue(storage.save(old))
        storage.remove = { _ in throw CocoaError(.fileWriteNoPermission) }
        XCTAssertFalse(storage.clearRun())
        XCTAssertEqual(storage.loadRun()?.run.seed, old.run.seed)
        XCTAssertEqual(storage.loadRemoteRun()?.run.seed, old.run.seed,
                       "A failed delete rolls back the newly written discard receipt")
        XCTAssertEqual(cloud.publishes, 1)
    }

    func testUnreadableRunIsNotTreatedAsAnAlreadyMissingFile() throws {
        let cloud = RunCloudProbe()
        var storage = try makeStorage(cloud)
        let old = Game(seed: "unreadable-local")
        XCTAssertTrue(storage.save(old))
        let originalRead = storage.read
        storage.read = { url in
            if url.lastPathComponent == "run.json" { throw CocoaError(.fileReadNoPermission) }
            return try originalRead(url)
        }
        XCTAssertFalse(storage.clearRun())
        XCTAssertEqual(storageFor(directory: storage.directory, cloud: cloud).loadRun()?.run.seed, old.run.seed)
        XCTAssertEqual(cloud.publishes, 1)
    }

    func testDiscardReceiptMustBeDurableBeforeRemovingTheRun() throws {
        let cloud = RunCloudProbe()
        var storage = try makeStorage(cloud)
        let old = Game(seed: "discard-write-error")
        XCTAssertTrue(storage.save(old))
        let originalWrite = storage.write
        storage.write = { data, url in
            if url.lastPathComponent == "discarded-runs.json" { throw CocoaError(.fileWriteNoPermission) }
            try originalWrite(data, url)
        }
        XCTAssertFalse(storage.clearRun())
        XCTAssertEqual(storage.loadRun()?.run.seed, old.run.seed)
        XCTAssertEqual(cloud.publishes, 1)
    }

    func testRemoteOnlyAbandonAndRepeatedMissingFileClearAreSuccessful() throws {
        let cloud = RunCloudProbe()
        let storage = try makeStorage(cloud)
        let remote = Game(seed: "remote-only")
        try cloud.deliverLegacy(remote)
        XCTAssertTrue(storage.clearRun())
        XCTAssertNil(storage.displayedRun())
        XCTAssertTrue(storage.clearRun())
        try cloud.deliverLegacy(remote)
        XCTAssertNil(storage.displayedRun())
    }

    func testResumeKeepsLocalAuthorityEvenWhenBackingUpAnAlternativeTemporarilyFails() throws {
        let cloud = RunCloudProbe()
        var storage = try makeStorage(cloud)
        let local = Game(seed: "conflict-local")
        let remote = Game(seed: "conflict-remote")
        XCTAssertTrue(storage.save(local))
        try cloud.deliverLegacy(remote)
        let conflict = RunStore.Conflict(local: local, remote: remote)
        XCTAssertNil(storage.conflict())
        XCTAssertEqual(cloud.publishes, 1)
        storage.write = { _, _ in throw CocoaError(.fileWriteNoPermission) }
        XCTAssertNil(storage.choose(.remote, from: conflict))
        XCTAssertEqual(storage.resumeRun()?.run.seed, local.run.seed)
        XCTAssertEqual(storage.loadRun()?.run.seed, local.run.seed)
        XCTAssertEqual(storage.loadRemoteRun()?.run.seed, remote.run.seed)
        XCTAssertEqual(cloud.publishes, 1)
        let working = storageFor(directory: storage.directory, cloud: cloud)
        XCTAssertNil(working.choose(.remote, from: conflict))
        XCTAssertNil(working.conflict())
        XCTAssertEqual(working.resumeRun()?.run.seed, local.run.seed)
        XCTAssertNil(working.loadRemoteRun(), "The archived alternative is never a second Continue candidate")
    }

    func testFailedRemoteAdoptionDoesNotPretendTheBookWasSavedLocally() throws {
        let cloud = RunCloudProbe()
        var storage = try makeStorage(cloud)
        try cloud.deliverLegacy(Game(seed: "remote-adoption-error"))
        storage.write = { _, _ in throw CocoaError(.fileWriteNoPermission) }
        XCTAssertNil(storage.resumeRun())
        XCTAssertNil(storage.loadRun())
        XCTAssertEqual(storage.loadRemoteRun()?.run.seed, "remote-adoption-error")
        XCTAssertEqual(cloud.publishes, 0)
    }

    func testLocalOnlyCheckpointCannotPublishOrForgetDiscardedIdentities() throws {
        let cloud = RunCloudProbe()
        let storage = try makeStorage(cloud)
        let old = Game(seed: "old-discarded")
        XCTAssertTrue(storage.save(old))
        XCTAssertTrue(storage.clearRun())
        let current = Game(seed: "checkpoint-local-only")
        XCTAssertTrue(storage.save(current, publishToCloud: false))
        XCTAssertEqual(storage.loadRun()?.run.seed, current.run.seed)
        XCTAssertEqual(cloud.publishes, 2)
        try cloud.deliverLegacy(old)
        XCTAssertNil(storage.loadRemoteRun())
    }

    func testCompletedReceiptsRemainSavedButTerminalFailureDiscardsItsAttempt() throws {
        let cloud = RunCloudProbe()
        let storage = try makeStorage(cloud)
        var completed = RunState(seed: "completed-receipt")
        completed.outcome = .bookCompleted
        XCTAssertTrue(storage.save(Game(run: completed)))
        XCTAssertEqual(storage.loadRun()?.run.outcome, .bookCompleted)
        var failed = RunState(seed: "failed-attempt")
        XCTAssertTrue(storage.replace(expected: Game(run: completed), with: Game(run: failed)))
        failed.outcome = .failed
        XCTAssertTrue(storage.save(Game(run: failed)))
        XCTAssertNil(storage.loadRun())
        try cloud.deliverLegacy(Game(seed: "failed-attempt"))
        XCTAssertNil(storage.loadRemoteRun())
    }

    func testFailedRemoveAndFailedReceiptRollbackDoNotDiscardTheStillExistingRun() throws {
        let cloud = RunCloudProbe()
        var storage = try makeStorage(cloud)
        let game = Game(seed: "double-io-failure")
        XCTAssertTrue(storage.save(game))
        let localBytes = try Data(contentsOf: storage.directory.appendingPathComponent("run.json"))
        let remoteBytes = cloud.envelope
        let originalWrite = storage.write
        var receiptWrites = 0
        storage.write = { data, url in
            if url.lastPathComponent == "discarded-runs.json" {
                receiptWrites += 1
                if receiptWrites > 1 { throw CocoaError(.fileWriteNoPermission) }
            }
            try originalWrite(data, url)
        }
        storage.remove = { _ in throw CocoaError(.fileWriteNoPermission) }
        XCTAssertFalse(storage.clearRun())
        XCTAssertEqual(try Data(contentsOf: storage.directory.appendingPathComponent("run.json")), localBytes)
        XCTAssertEqual(cloud.envelope, remoteBytes)
        XCTAssertEqual(storage.loadRemoteRun()?.run.seed, game.run.seed)
        XCTAssertEqual(storageFor(directory: storage.directory, cloud: cloud).loadRemoteRun()?.run.seed, game.run.seed)
    }

    func testPendingReceiptProtectsDeletionWhenFinalizationWriteFailsAndSurvivesSameSeedRestart() throws {
        let cloud = RunCloudProbe()
        var storage = try makeStorage(cloud)
        let game = Game(seed: "pending-deletion")
        XCTAssertTrue(storage.save(game))
        let originalWrite = storage.write
        var receiptWrites = 0
        storage.write = { data, url in
            if url.lastPathComponent == "discarded-runs.json" {
                receiptWrites += 1
                if receiptWrites > 1 { throw CocoaError(.fileWriteNoPermission) }
            }
            try originalWrite(data, url)
        }
        XCTAssertTrue(storage.clearRun(), "Deletion plus the durable pending receipt completes abandonment")
        try cloud.deliverLegacy(game)
        let reopened = storageFor(directory: storage.directory, cloud: cloud)
        XCTAssertNil(reopened.loadRun())
        XCTAssertNil(reopened.loadRemoteRun())
        XCTAssertTrue(reopened.save(Game(seed: game.run.seed)))
        XCTAssertEqual(reopened.loadRun()?.run.seed, game.run.seed)
        XCTAssertNil(reopened.loadRemoteRun(), "Same-seed local restart must settle the pending deletion first")
    }

    func testLegacyRemoteChoiceCannotSwitchTheLocalAuthority() throws {
        let cloud = RunCloudProbe()
        let storage = try makeStorage(cloud)
        let local = Game(seed: "stable-local")
        XCTAssertTrue(storage.save(local))
        try cloud.deliverLegacy(Game(seed: "remote-at-opening"))
        let conflict = RunStore.Conflict(local: local, remote: Game(seed: "remote-at-opening"))
        let newer = Game(seed: "remote-arrived-later")
        try cloud.deliverLegacy(newer)
        let localBytes = try Data(contentsOf: storage.directory.appendingPathComponent("run.json"))
        let remoteBytes = cloud.envelope
        XCTAssertNil(storage.choose(.remote, from: conflict))
        XCTAssertEqual(storage.choose(.local, from: conflict)?.run.seed, local.run.seed)
        XCTAssertEqual(try Data(contentsOf: storage.directory.appendingPathComponent("run.json")), localBytes)
        XCTAssertEqual(cloud.envelope, remoteBytes)
        XCTAssertEqual(cloud.publishes, 1)
        XCTAssertNil(storage.conflict())
        XCTAssertNil(storage.loadRemoteRun())
    }

    func testReplacementAtomicallySavesTheNewBookAndRejectsStaleOldCloudState() throws {
        let cloud = RunCloudProbe()
        var storage = try makeStorage(cloud)
        let old = Game(seed: "replacement-old")
        let new = Game(seed: "replacement-new", book: .smallVictories)
        XCTAssertTrue(storage.save(old))
        storage.remove = { _ in XCTFail("Replacement must overwrite atomically, never delete the old run first") }

        XCTAssertTrue(storage.replace(expected: old, with: new))

        XCTAssertEqual(storage.loadRun()?.run.seed, new.run.seed)
        XCTAssertEqual(storage.resumeRun()?.run.seed, new.run.seed)
        XCTAssertEqual(RunStore.game(from: cloud.snapshot.data)?.run.seed, new.run.seed)
        XCTAssertTrue(cloud.snapshot.discardedRuns.contains(RunStore.DiscardedRunIdentity(old)))
        let committedBytes = try Data(contentsOf: storage.directory.appendingPathComponent("run.json"))
        XCTAssertFalse(storage.replace(expected: old, with: new), "A repeated acceptance is stale")
        XCTAssertEqual(try Data(contentsOf: storage.directory.appendingPathComponent("run.json")), committedBytes)
        try cloud.deliverLegacy(old, modifiedAt: 9_999_999_999)
        let reopened = storageFor(directory: storage.directory, cloud: cloud)
        XCTAssertNil(reopened.loadRemoteRun())
        XCTAssertEqual(reopened.resumeRun()?.run.seed, new.run.seed)
        XCTAssertEqual(cloud.publishes, 2)
    }

    func testReplacementWriteAndRollbackFailuresPreserveLocalAndRemoteOnlyOldBooks() throws {
        for hasLocal in [true, false] {
            let cloud = RunCloudProbe()
            var storage = try makeStorage(cloud)
            let old = Game(seed: "replacement-write-error-\(hasLocal)")
            if hasLocal { XCTAssertTrue(storage.save(old)) }
            else { try cloud.deliverLegacy(old) }
            let originalEnvelope = cloud.envelope
            let originalWrite = storage.write
            var receiptWrites = 0
            storage.write = { data, url in
                if url.lastPathComponent == "run.json" { throw CocoaError(.fileWriteNoPermission) }
                if url.lastPathComponent == "discarded-runs.json" {
                    receiptWrites += 1
                    if receiptWrites > 1 { throw CocoaError(.fileWriteNoPermission) }
                }
                try originalWrite(data, url)
            }

            XCTAssertFalse(storage.replace(expected: old, with: Game(seed: "unsaved-replacement")))

            let reopened = storageFor(directory: storage.directory, cloud: cloud)
            XCTAssertEqual(reopened.loadRun()?.run.seed, hasLocal ? old.run.seed : nil)
            XCTAssertEqual(reopened.loadRemoteRun()?.run.seed, old.run.seed)
            XCTAssertEqual(reopened.displayedRun()?.run.seed, old.run.seed)
            XCTAssertEqual(cloud.envelope, originalEnvelope)
            XCTAssertEqual(cloud.publishes, hasLocal ? 1 : 0)
        }
    }

    func testReplacementSurvivesReceiptFinalizationFailureAfterAtomicRunWrite() throws {
        for hasLocal in [true, false] {
            let cloud = RunCloudProbe()
            var storage = try makeStorage(cloud)
            let old = Game(seed: "replacement-finalize-old-\(hasLocal)")
            let new = Game(seed: "replacement-finalize-new-\(hasLocal)")
            if hasLocal { XCTAssertTrue(storage.save(old)) }
            else { try cloud.deliverLegacy(old) }
            let originalWrite = storage.write
            var receiptWrites = 0
            storage.write = { data, url in
                if url.lastPathComponent == "discarded-runs.json" {
                    receiptWrites += 1
                    if receiptWrites > 1 { throw CocoaError(.fileWriteNoPermission) }
                }
                try originalWrite(data, url)
            }

            XCTAssertTrue(storage.replace(expected: old, with: new),
                          "The new run plus its pending receipt already completes replacement")
            try cloud.deliverLegacy(old)
            let reopened = storageFor(directory: storage.directory, cloud: cloud)
            XCTAssertEqual(reopened.loadRun()?.run.seed, new.run.seed)
            XCTAssertNil(reopened.loadRemoteRun())
            XCTAssertEqual(reopened.resumeRun()?.run.seed, new.run.seed)
            XCTAssertTrue(reopened.save(new), "The next checkpoint can normalize the pending receipt")
            XCTAssertNil(reopened.conflict())
        }
    }

    func testReplacementRequiresDurableReceiptBeforeChangingTheOldRun() throws {
        let cloud = RunCloudProbe()
        var storage = try makeStorage(cloud)
        let old = Game(seed: "replacement-receipt-error")
        XCTAssertTrue(storage.save(old))
        let originalBytes = try Data(contentsOf: storage.directory.appendingPathComponent("run.json"))
        let originalEnvelope = cloud.envelope
        storage.write = { _, _ in throw CocoaError(.fileWriteNoPermission) }
        XCTAssertFalse(storage.replace(expected: old, with: Game(seed: "uncommitted-new")))
        XCTAssertEqual(try Data(contentsOf: storage.directory.appendingPathComponent("run.json")), originalBytes)
        XCTAssertEqual(cloud.envelope, originalEnvelope)
        XCTAssertEqual(cloud.publishes, 1)
    }

    func testReplacementUsesExactLocalAuthorityAndRejectsChangedRemoteOnlyState() throws {
        for hasLocal in [true, false] {
            let cloud = RunCloudProbe()
            let storage = try makeStorage(cloud)
            let expected = Game(seed: "replacement-expected-\(hasLocal)")
            if hasLocal { XCTAssertTrue(storage.save(expected)) }
            else { try cloud.deliverLegacy(expected) }
            let newer = Game(seed: "replacement-newer-remote-\(hasLocal)")
            try cloud.deliverLegacy(newer)
            let originalEnvelope = cloud.envelope
            let replacement = Game(seed: "explicit-replacement")
            XCTAssertEqual(storage.replace(expected: expected, with: replacement), hasLocal)
            if hasLocal {
                XCTAssertEqual(storage.loadRun()?.run.seed, replacement.run.seed)
                XCTAssertTrue(cloud.snapshot.discardedRuns.contains(RunStore.DiscardedRunIdentity(newer)))
                XCTAssertTrue(try archivedEnvelopes(storage).contains(try XCTUnwrap(originalEnvelope)))
            } else {
                XCTAssertNil(storage.loadRun())
                XCTAssertEqual(storage.loadRemoteRun()?.run.seed, newer.run.seed)
                XCTAssertEqual(cloud.envelope, originalEnvelope)
            }
        }
    }

    func testCompletionWriteFailurePreservesPriorUnlocksAndCanBeRetried() throws {
        let cloud = RunCloudProbe()
        var storage = try makeStorage(cloud)
        XCTAssertTrue(storage.recordBookCompleted(.probably, obstacle: .none))
        let url = storage.directory.appendingPathComponent("progress.json")
        let originalBytes = try Data(contentsOf: url)
        storage.write = { _, _ in throw CocoaError(.fileWriteNoPermission) }

        XCTAssertFalse(storage.recordBookCompleted(.smallVictories, obstacle: .shortHanded))
        XCTAssertEqual(try Data(contentsOf: url), originalBytes)
        let reopened = storageFor(directory: storage.directory, cloud: cloud)
        XCTAssertTrue(reopened.recordBookCompleted(.smallVictories, obstacle: .shortHanded))
        let progress = try JSONDecoder().decode(RunStore.Progress.self, from: Data(contentsOf: url))
        XCTAssertTrue(progress.completedBooks.contains(Book.probably.rawValue))
        XCTAssertTrue(progress.completedBooks.contains(Book.smallVictories.rawValue))
        XCTAssertEqual(progress.completedObstacles[Book.smallVictories.rawValue], Obstacle.shortHanded.rawValue)
        XCTAssertEqual(cloud.publishes, 0, "Completion progress writes are separate from run cloud transport")
    }

    func testAlreadyDurableCompletionSucceedsWithoutAnotherWrite() throws {
        let cloud = RunCloudProbe()
        var storage = try makeStorage(cloud)
        XCTAssertTrue(storage.recordBookCompleted(.probably, obstacle: .shortHanded))
        storage.write = { _, _ in
            XCTFail("An already recorded completion needs no write")
            throw CocoaError(.fileWriteNoPermission)
        }
        XCTAssertTrue(storage.recordBookCompleted(.probably, obstacle: .shortHanded))
        XCTAssertTrue(storage.recordBookCompleted(.probably, obstacle: .none))
    }

    func testUnreadableCompletionProgressCannotBeReplacedWithEmptyProgress() throws {
        let cloud = RunCloudProbe()
        var storage = try makeStorage(cloud)
        XCTAssertTrue(storage.recordBookCompleted(.probably, obstacle: .none))
        let url = storage.directory.appendingPathComponent("progress.json")
        let originalBytes = try Data(contentsOf: url)
        let originalRead = storage.read
        storage.read = { url in
            if url.lastPathComponent == "progress.json" { throw CocoaError(.fileReadNoPermission) }
            return try originalRead(url)
        }
        XCTAssertFalse(storage.recordBookCompleted(.smallVictories, obstacle: .none))
        XCTAssertEqual(try Data(contentsOf: url), originalBytes)
        let reopened = storageFor(directory: storage.directory, cloud: cloud)
        let corruptBytes = Data("preserve-unrecognized-progress".utf8)
        try corruptBytes.write(to: url, options: .atomic)
        XCTAssertFalse(reopened.recordBookCompleted(.smallVictories, obstacle: .none))
        XCTAssertEqual(try Data(contentsOf: url), corruptBytes)
    }

    /// Create distinct saved checkpoints using accepted gameplay actions.
    /// Advancing an unopened Book is intentionally rejected by Game.advance().
    private func advancedCheckpoint(_ original: Game, turns: Int = 1,
                                    file: StaticString = #filePath, line: UInt = #line) throws -> Game {
        var checkpoint = original
        try checkpoint.startPuzzle()
        for _ in 0..<turns { _ = try checkpoint.endTurn() }
        XCTAssertEqual(checkpoint.puzzle?.turnNumber, turns + 1, file: file, line: line)
        XCTAssertNotEqual(try checkpoint.encoded(), try original.encoded(), file: file, line: line)
        XCTAssertNotNil(RunStore.conflict(local: original, remote: checkpoint), file: file, line: line)
        return checkpoint
    }

    private func makeStorage(_ cloud: RunCloudProbe) throws -> RunStore.Storage {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("run-storage-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return storageFor(directory: directory, cloud: cloud)
    }

    private func archivedEnvelopes(_ storage: RunStore.Storage) throws -> [Data] {
        let urls = try FileManager.default.contentsOfDirectory(
            at: storage.directory.appendingPathComponent("run-backups"), includingPropertiesForKeys: nil)
        return try urls.compactMap { url in
            let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
            return (object?["cloudEnvelope"] as? String).flatMap { Data(base64Encoded: $0) }
        }
    }

    private func storageFor(directory: URL, cloud: RunCloudProbe) -> RunStore.Storage {
        RunStore.Storage(directory: directory, remoteSnapshot: { cloud.snapshot },
            publish: { cloud.publish($0, discardedRuns: $1) })
    }
}

private final class RunCloudProbe {
    var envelope: Data?
    var publishes = 0
    var snapshot: CloudSync.RunSnapshot { CloudSync.runSnapshot(fromEnvelope: envelope) }

    func deliverLegacy(_ game: Game, modifiedAt: Double = 0) throws {
        envelope = try JSONSerialization.data(withJSONObject: [
            "schema": 1, "modifiedAt": modifiedAt, "payload": game.encoded().base64EncodedString()
        ])
    }

    func publish(_ data: Data?, discardedRuns: [RunStore.DiscardedRunIdentity]) {
        publishes += 1
        let next = CloudSync.snapshotAfterPublishing(run: data, discardedRuns: discardedRuns, previous: snapshot)
        envelope = try? CloudSync.encodedRunEnvelope(next)
    }
}
