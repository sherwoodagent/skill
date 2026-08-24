// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

/// @dev Mirrors `ICallSandbox.Call` on origin/post-audit: `(address target, bytes data)`.
///      No `value` field - native transfer is refused by construction.
interface ICallSandbox {
    struct Call {
        address target;
        bytes data;
    }
}

interface ISyndicateGovernor {
    struct Call {
        address target;
        bytes data;
        uint256 value;
    }

    struct StrategyProposal {
        uint256 id;
        address proposer;
        address vault;
        string metadataURI;
        uint256 splitIndex;
        uint256 strategyDuration;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 snapshotTimestamp;
        uint256 voteEnd;
        uint256 executeBy;
        uint256 executedAt;
        uint8 state;
    }

    /// @dev Field order matches `ISyndicateGovernor.SandboxPayload`:
    ///      `funding`, `calls`, `declaredTokens`.
    struct SandboxPayload {
        uint256 funding;
        ICallSandbox.Call[] calls;
        address[] declaredTokens;
    }

    function getProposal(uint256 proposalId) external view returns (StrategyProposal memory);
    function getExecuteCalls(uint256 proposalId) external view returns (Call[] memory);
    function getSettlementCalls(uint256 proposalId) external view returns (Call[] memory);
    function getCapitalSnapshot(uint256 proposalId) external view returns (uint256);
    function sandboxPayload(uint256 proposalId) external view returns (SandboxPayload memory);
}

interface ISyndicateVault {
    function asset() external view returns (address);
    function totalAssets() external view returns (uint256);
    function agentFeeBps() external view returns (uint256);
    function sandboxImplementation() external view returns (address);
}

/// @dev Target that succeeds only when `msg.sender` is the vault. The
///      discriminating test's payload: a vault-sender sim passes, the
///      clone-sender sim (what `CallSandbox.run` actually does) fails.
contract VaultGatedTarget {
    address public immutable vault;

    constructor(address vault_) {
        vault = vault_;
    }

    function onlyVaultMayCall() external view {
        require(msg.sender == vault, "not vault");
    }
}

/// @title SimulateProposal - Fork-test a governance proposal before it auto-passes
/// @notice Run with env vars: PROPOSAL_ID, GOVERNOR_ADDRESS, VAULT_ADDRESS
/// @dev forge test --fork-url $RPC_URL --match-test test_simulateProposalCalls -vvvv
///
///      Execute order is load-bearing (`SyndicateGovernor.execute`, origin/post-audit
///      ~884-889): `vault.runSandbox(...)` FIRST, then `vault.executeGovernorBatch`.
///      Sandbox sub-calls are dispatched from the clone (`CallSandbox.run` does
///      `c.target.call(c.data)`), never from the vault. Simulating them as the
///      vault is the exact failure the sandbox exists to prevent.
contract SimulateProposal is Test {
    function test_simulateProposalCalls() public {
        uint256 proposalId = vm.envUint("PROPOSAL_ID");
        address governor = vm.envAddress("GOVERNOR_ADDRESS");
        address vault = vm.envAddress("VAULT_ADDRESS");

        // Fetch proposal metadata
        ISyndicateGovernor.StrategyProposal memory proposal = ISyndicateGovernor(governor).getProposal(proposalId);

        emit log_named_address("Proposer", proposal.proposer);
        emit log_named_address("Vault", proposal.vault);
        emit log_named_string("Metadata URI", proposal.metadataURI);
        emit log_named_uint("Strategy Duration (s)", proposal.strategyDuration);
        // The agent fee is no longer a per-proposal input - it lives on the vault
        // as `agentFeeBps` (vault owner sets it via `vault.setAgentFeeBps`). The
        // governor snapshots the vault's `agentFeeBps` onto the proposal at propose
        // time and uses that snapshot, clamped to `maxPerformanceFeeBps`, at settlement.
        emit log_named_uint("Vault agent fee (bps)", ISyndicateVault(vault).agentFeeBps());
        emit log_named_uint("State", uint256(proposal.state));

        address asset = ISyndicateVault(vault).asset();
        uint256 balanceBefore = IERC20(asset).balanceOf(vault);
        emit log_string("===");
        emit log_named_address("Vault asset", asset);
        emit log_named_uint("Vault balance BEFORE", balanceBefore);

        // 1. Sandbox path - BEFORE the batch, from the clone. Matches
        //    `SyndicateVault.runSandbox`: deterministic clone at
        //    `Clones.cloneDeterministic(impl, bytes32(pid))` (deployer = vault),
        //    push funding, then `CallSandbox.run` which calls each target as
        //    the clone.
        ISyndicateGovernor.SandboxPayload memory sandbox = ISyndicateGovernor(governor).sandboxPayload(proposalId);
        if (sandbox.calls.length != 0) {
            address impl = ISyndicateVault(vault).sandboxImplementation();
            address clone = predictSandboxClone(impl, proposalId, vault);
            emit log_string("--- sandbox ---");
            emit log_named_address("Sandbox implementation", impl);
            emit log_named_address("Sandbox clone", clone);
            emit log_named_uint("Sandbox funding", sandbox.funding);
            emit log_named_uint("Sandbox calls", sandbox.calls.length);
            for (uint256 i = 0; i < sandbox.calls.length; i++) {
                emit log_string("---");
                emit log_named_uint("Sandbox call index", i);
                emit log_named_address("Target", sandbox.calls[i].target);
                emit log_named_bytes("Data", sandbox.calls[i].data);
            }
            if (sandbox.funding != 0) {
                vm.prank(vault);
                IERC20(asset).transfer(clone, sandbox.funding);
            }
            simulateSandboxCalls(clone, sandbox.calls);
        }

        // 2. Governor batch - execute then settle, as the vault. The
        //    legacy `getProposalCalls` concat helper was dropped in V1.5;
        //    we now build the unified array off-chain to keep simulation
        //    semantics identical (executeCalls run first, then settleCalls).
        ISyndicateGovernor.Call[] memory exec = ISyndicateGovernor(governor).getExecuteCalls(proposalId);
        ISyndicateGovernor.Call[] memory settle = ISyndicateGovernor(governor).getSettlementCalls(proposalId);
        ISyndicateGovernor.Call[] memory calls = new ISyndicateGovernor.Call[](exec.length + settle.length);
        for (uint256 i = 0; i < exec.length; i++) {
            calls[i] = exec[i];
        }
        for (uint256 i = 0; i < settle.length; i++) {
            calls[exec.length + i] = settle[i];
        }

        emit log_named_uint("Number of batch calls", calls.length);

        for (uint256 i = 0; i < calls.length; i++) {
            emit log_string("---");
            emit log_named_uint("Call index", i);
            emit log_named_address("Target", calls[i].target);
            emit log_named_uint("Value", calls[i].value);
            emit log_named_bytes("Data", calls[i].data);

            if (calls[i].data.length >= 4) {
                bytes4 selector;
                assembly {
                    selector := mload(add(mload(add(calls, mul(add(i, 1), 0x20))), 0x60))
                }
                emit log_named_bytes32("Selector", bytes32(selector));
            }
        }

        simulateBatchCalls(vault, calls);

        uint256 balanceAfter = IERC20(asset).balanceOf(vault);
        emit log_string("===");
        emit log_named_uint("Vault balance AFTER", balanceAfter);

        if (balanceAfter >= balanceBefore) {
            emit log_named_uint("Balance INCREASE", balanceAfter - balanceBefore);
        } else {
            emit log_named_uint("Balance DECREASE", balanceBefore - balanceAfter);
        }
    }

    function test_simulateSettlement() public {
        uint256 proposalId = vm.envUint("PROPOSAL_ID");
        address governor = vm.envAddress("GOVERNOR_ADDRESS");
        address vault = vm.envAddress("VAULT_ADDRESS");

        // Get capital snapshot for P&L comparison
        uint256 capitalSnapshot = ISyndicateGovernor(governor).getCapitalSnapshot(proposalId);
        emit log_named_uint("Capital snapshot", capitalSnapshot);

        address asset = ISyndicateVault(vault).asset();
        uint256 currentBalance = IERC20(asset).balanceOf(vault);
        emit log_named_uint("Current balance", currentBalance);

        if (currentBalance >= capitalSnapshot) {
            emit log_named_uint("Profit", currentBalance - capitalSnapshot);
        } else {
            emit log_named_uint("Loss", capitalSnapshot - currentBalance);
        }

        // Settlement simulation: try calling settleProposal
        // This verifies the proposal CAN be settled without reverting
        (bool success,) = governor.call(abi.encodeWithSignature("settleProposal(uint256)", proposalId));
        assertTrue(success, "settleProposal would revert - needs emergency settle");
    }

    /// @notice Proves the harness is simulating the sandbox caller, not the vault.
    ///         A `msg.sender == vault` payload PASSES a vault-sender sim (the old
    ///         bug) and FAILS the clone-sender sim `CallSandbox.run` actually
    ///         performs. That discrimination is the whole security argument for
    ///         the sandbox.
    function test_sandboxPayloadPassesVaultSenderSimAndFailsCloneSenderSim() public {
        address vault = address(0xA11CE);
        address impl = address(0xB0B);
        uint256 proposalId = 1;
        address clone = predictSandboxClone(impl, proposalId, vault);
        assertTrue(clone != vault, "clone must not be the vault");
        assertTrue(clone != address(0), "clone must be a real CREATE2 address");

        VaultGatedTarget target = new VaultGatedTarget(vault);
        ICallSandbox.Call[] memory calls = new ICallSandbox.Call[](1);
        calls[0] = ICallSandbox.Call({
            target: address(target),
            data: abi.encodeCall(VaultGatedTarget.onlyVaultMayCall, ())
        });

        // Wrong caller: vault. This is what the old harness did for every call,
        // and it is exactly the identity `CallSandbox` exists to strip.
        vm.prank(vault);
        (bool passAsVault,) = calls[0].target.call(calls[0].data);
        assertTrue(passAsVault, "vault-sender sim would pass this payload");

        // Correct caller: the clone. Same calldata, same target, fails.
        vm.prank(clone);
        (bool passAsClone,) = calls[0].target.call(calls[0].data);
        assertFalse(passAsClone, "clone-sender sim must fail this payload");

        // The harness helper used by `test_simulateProposalCalls` is the clone
        // path, so this payload reverts there too - proving the fork sim is
        // not still pranking as the vault.
        vm.expectRevert();
        this.simulateSandboxCalls(clone, calls);
    }

    /// @dev ERC-1167 + CREATE2, matching OpenZeppelin `Clones.cloneDeterministic`
    ///      as called from the vault with `salt = bytes32(proposalId)`.
    function predictSandboxClone(address implementation, uint256 proposalId, address vault)
        public
        pure
        returns (address)
    {
        bytes32 salt = bytes32(proposalId);
        bytes32 bytecodeHash = keccak256(
            abi.encodePacked(
                hex"3d602d80600a3d3981f3363d3d373d3d3d363d73",
                bytes20(implementation),
                hex"5af43d82803e903d91602b57fd5bf3"
            )
        );
        return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), vault, salt, bytecodeHash)))));
    }

    /// @dev Dispatch stored sandbox calls as the clone. Public so the
    ///      discriminating test can `expectRevert` on `this.simulateSandboxCalls`.
    function simulateSandboxCalls(address clone, ICallSandbox.Call[] memory calls) public {
        vm.startPrank(clone);
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory ret) = calls[i].target.call(calls[i].data);
            assertTrue(success, string(abi.encodePacked("Sandbox call ", vm.toString(i), " FAILED")));
            emit log_named_uint("Sandbox call succeeded", i);
            emit log_named_bytes("Return data", ret);
        }
        vm.stopPrank();
    }

    function simulateBatchCalls(address vault, ISyndicateGovernor.Call[] memory calls) internal {
        vm.startPrank(vault);
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory ret) = calls[i].target.call{value: calls[i].value}(calls[i].data);
            assertTrue(success, string(abi.encodePacked("Call ", vm.toString(i), " FAILED")));
            emit log_named_uint("Call succeeded", i);
            emit log_named_bytes("Return data", ret);
        }
        vm.stopPrank();
    }
}
