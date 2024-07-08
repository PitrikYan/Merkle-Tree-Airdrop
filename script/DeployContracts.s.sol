//SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {MerkleAirdrop} from "../src/MerkleAirdrop.sol";
import {VacuumToken} from "../src/VacuumToken.sol";
import {Script, console} from "forge-std/Script.sol";

contract DeployContracts is Script {
    bytes32 public constant ROOT = 0x9335a07b393fa3eb382c11e887392af4abc10680ff91a264ed0a2def5ebed8ec;
    string public constant TOKEN_NAME = "Vacuum";
    string public constant TOKEN_SYMBOL = "VAC";
    uint256 public constant AMOUNT_CLAIM = 25 ether;
    uint256 public constant AMOUNT_MINT = AMOUNT_CLAIM * 4;

    function deployContracts() public returns (MerkleAirdrop, VacuumToken) {
        vm.startBroadcast();
        VacuumToken vacuumToken = new VacuumToken(TOKEN_NAME, TOKEN_SYMBOL);
        MerkleAirdrop merkleAirdrop = new MerkleAirdrop(ROOT, vacuumToken);

        vacuumToken.mint(address(merkleAirdrop), AMOUNT_MINT);
        vm.stopBroadcast();

        return (merkleAirdrop, vacuumToken);
    }

    function run() external returns (MerkleAirdrop, VacuumToken) {
        return deployContracts();
    }
}
