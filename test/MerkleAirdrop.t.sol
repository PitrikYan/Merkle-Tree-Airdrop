//SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {MerkleAirdrop} from "../src/MerkleAirdrop.sol";
import {VacuumToken} from "../src/VacuumToken.sol";
import {ZkSyncChainChecker} from "foundry-devops/ZkSyncChainChecker.sol"; // its trying to call the precomiles which are not yet exists on zksync
import {DeployContracts} from "../script/DeployContracts.s.sol";

contract MerkeAirdropTest is ZkSyncChainChecker, Test {
    MerkleAirdrop public merkleAirdrop;
    VacuumToken public token;
    bytes32 public constant ROOT = 0x9335a07b393fa3eb382c11e887392af4abc10680ff91a264ed0a2def5ebed8ec;
    uint256 public constant AMOUNT_CLAIM = 25 ether;
    uint256 public constant AMOUNT_MINT = AMOUNT_CLAIM * 4;

    address public user;
    uint256 public userKey;

    address public callerGasPayer;

    function setUp() public {
        // zksync now doesnt support scripts for deploying..
        if (!isZkSyncChain()) {
            // use scripts
            DeployContracts deployer = new DeployContracts();
            (merkleAirdrop, token) = deployer.run();
        } else {
            // on zksync deploy here
            token = new VacuumToken("Vacuum", "VAC");
            merkleAirdrop = new MerkleAirdrop(ROOT, token);
            token.mint(address(merkleAirdrop), AMOUNT_MINT);
        }

        (user, userKey) = makeAddrAndKey("Karel");
        callerGasPayer = makeAddr("Stana");
    }

    function test_userCanClaim() public {
        //console.log("user addr: ", user);

        bytes32 messageHash = merkleAirdrop.getMessageHash(user, AMOUNT_CLAIM);

        bytes32[] memory proof = new bytes32[](2);
        proof[0] = 0x65bfaf138fd19bc815f5a06bdd23de5efc7c3e7f3f8c014560c5e0e74ed3f796;
        proof[1] = 0x181d132ef2e7a0da3638cd6b9e6ec8242f74568bc4dfd28f969a549814774e5f;

        bool claimedBefore = merkleAirdrop.isClaimed(user);
        uint256 balanceBefore = token.balanceOf(user);
        assert(!claimedBefore);
        assertEq(balanceBefore, 0);

        //vm.prank(user); // to sign message WE JUST NEED PRIVATE KEY and could be anybody!
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userKey, messageHash);

        vm.prank(callerGasPayer); // gas payer call claim aurdrop for us with the signature
        merkleAirdrop.claimDrop(user, AMOUNT_CLAIM, proof, v, r, s);

        bool claimedAfter = merkleAirdrop.isClaimed(user);
        uint256 balanceAfter = token.balanceOf(user);
        assert(claimedAfter);
        assertEq(balanceAfter, AMOUNT_CLAIM);
    }
}
