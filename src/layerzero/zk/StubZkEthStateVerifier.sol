// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IZkEthStateVerifier} from "./IZkEthStateVerifier.sol";

contract StubZkEthStateVerifier is IZkEthStateVerifier {
    bool public constant STUB_RESULT = true;
    
    function verifySourceEvent(bytes calldata, Inputs calldata)
        external pure override returns (bool) {
        return STUB_RESULT;
    }
}