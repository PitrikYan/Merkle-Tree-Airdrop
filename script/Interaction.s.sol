//SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {MerkleAirdrop} from "../src/MerkleAirdrop.sol";
import {DevOpsTools} from "foundry-devops/DevOpsTools.sol";

contract ClaimAirdrop is Script {
    error ClaimAirdropScript__InvalidSignatureLength();

    address constant CLAIM_ADDR = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8; // this is one of anvil accounts
    uint256 constant CLAIM_AMOUNT = 25 ether;
    bytes32 PROOF_ONE = 0xdc7479a528fc67c3f81ed45dd6316933b4f30024c76aa56f3577de243455a76d;
    bytes32 PROOF_TWO = 0x37c15d62c3b3b12269d59d1eada7a8dcb48a48ff0d8cce622899968d775dd814;
    bytes32[] proof = [PROOF_ONE, PROOF_TWO];

    /* we obtained a signature using:
       1. make deploy    // using deploy script to get the address of airdrop contract (0xe7f17...0512)
       2. cast call 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512 "getMessageHash(address,uint256)" 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 25000000000000000000 --rpc-url http://127.0.0.1:8545
       3. cast wallet sign --no-hash 0x3432df10de39de4c02e5302eb316301d2a4f039d0b7c5d3adec6c8c9d2fae22e --private-key 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
    */
    bytes private SIGNATURE =
        hex"77f1faa32b010b3a498433541abfeacbc91857eacc3d2f4ab978e45fa5f965e72ce848ebc1d90ae7be469aa1191f3a1b3cb5bea42f5f416161f313f3069620f11c";

    function claimAirdrop(address _merkleAirdrop) public {
        vm.startBroadcast();

        (uint8 v, bytes32 r, bytes32 s) = splitSignature(SIGNATURE);
        MerkleAirdrop(_merkleAirdrop).claimDrop(CLAIM_ADDR, CLAIM_AMOUNT, proof, v, r, s);

        vm.stopBroadcast();
    }

    function splitSignature(bytes memory _signature) internal pure returns (uint8 v, bytes32 r, bytes32 s) {
        if (_signature.length != 65) revert ClaimAirdropScript__InvalidSignatureLength();
        // when decoding a signature, r is first, s is second and then v
        assembly {
            r := mload(add(_signature, 0x20))
            s := mload(add(_signature, 0x40))
            v := byte(0, mload(add(_signature, 0x60)))
        }
    }

    function run() external {
        // get most recent deployed contract
        address mostRecentAirdrop = DevOpsTools.get_most_recent_deployment("MerkleAirdrop", block.chainid);
        claimAirdrop(mostRecentAirdrop);
    }
}
