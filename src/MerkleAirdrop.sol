//SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {IERC20, SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/utils/cryptography/MerkleProof.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/utils/cryptography/ECDSA.sol";

contract MerkleAirdrop is EIP712 {
    using MerkleProof for bytes32[];
    using SafeERC20 for IERC20; // Safe is a library..

    error MerkleAirdrop__InvalidProof();
    error MerkleAirdrop__AlreadyClaimed();
    error MerkleAirdrop__InvalidSignature();

    event Claimed(address indexed _account, uint256 indexed _amount);

    bytes32 private immutable i_merkleRoot;
    IERC20 private immutable i_token;

    // this is needed to get message for _hashTypedDataV4 from OZ
    bytes32 private constant MESSAGE_TYPEHASH = keccak256("AirdropClaim(address account,uint256 amount)");

    struct AirdropClaim {
        address account;
        uint256 amount;
    }

    mapping(address _user => bool _claimed) private s_hasClaimed;

    constructor(bytes32 _merkleRoot, IERC20 _token) EIP712("MerkleFckinAirdrop", "1.0.0") {
        i_merkleRoot = _merkleRoot;
        i_token = _token;
    }

    function claimDrop(
        address _account,
        uint256 _amount,
        bytes32[] calldata _merkleProof,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        if (s_hasClaimed[_account]) revert MerkleAirdrop__AlreadyClaimed();

        // check the signature
        if (!_isValidSignature(_account, getMessageHash(_account, _amount), v, r, s)) {
            revert MerkleAirdrop__InvalidSignature();
        }

        // make a leaf, double hash to avoid collisions
        bytes32 merkleLeaf = keccak256(bytes.concat(keccak256(abi.encode(_account, _amount))));

        if (!_merkleProof.verifyCalldata(i_merkleRoot, merkleLeaf)) revert MerkleAirdrop__InvalidProof();

        s_hasClaimed[_account] = true;
        emit Claimed(_account, _amount);

        i_token.safeTransfer(_account, _amount);
    }

    function getMessageHash(address _account, uint256 _amount) public view returns (bytes32) {
        return _hashTypedDataV4(
            keccak256(abi.encode(MESSAGE_TYPEHASH, AirdropClaim({account: _account, amount: _amount})))
        );
    }

    function _isValidSignature(address _account, bytes32 _message, uint8 _v, bytes32 _r, bytes32 _s)
        internal
        pure
        returns (bool)
    {
        (address recoveredSigner,,) = ECDSA.tryRecover(_message, _v, _r, _s);
        return recoveredSigner == _account;
    }

    /*  ##########################################
                        GETTERS
        ##########################################
    */

    function getRoot() external view returns (bytes32) {
        return i_merkleRoot;
    }

    function getToken() external view returns (IERC20) {
        return i_token;
    }

    function isClaimed(address _addr) external view returns (bool) {
        return s_hasClaimed[_addr];
    }
}
