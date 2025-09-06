// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

contract SettlementMock {
    bool private verificationResult = true;

    function setVerificationResult(bool result) external {
        verificationResult = result;
    }

    function getRequiredKeyTagFromValSetHeaderAt(uint48) public pure returns (bytes32) {
        return bytes32(uint256(15));
    }

    function getQuorumThresholdFromValSetHeaderAt(uint48) public pure returns (uint256) {
        return 100;
    }

    function getCaptureTimestampFromValSetHeaderAt(uint48) public pure returns (uint48) {
        return 1753887460;
    }

    function getLastCommittedHeaderEpoch() public pure returns (uint48) {
        return 1;
    }

    function verifyQuorumSigAt(bytes calldata, bytes32, uint256, bytes calldata, uint48, bytes calldata)
        public
        view
        returns (bool)
    {
        return verificationResult;
    }

    function verifyQuorumSig(bytes calldata, bytes32, uint256, bytes calldata) public view returns (bool) {
        return verificationResult;
    }
}
