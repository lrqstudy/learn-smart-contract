// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title 空投以及批量转账合约
 * @author lrqstudy
 * @notice 
 */
contract Airdrop {

    /**
     * 批量转token的合约
     * @param _token token地址
     * @param receivers 收款地址数组
     * @param receiveAmounts 收款金额数组
     */
    function batchTransferTokenToBatchAddress(
        address _token,
        address[] calldata receivers,
        uint256[] calldata receiveAmounts
    ) external {
        //批量转账. 当然对方要给
        require(
            receivers.length == receiveAmounts.length,
            "receivers length must equal receiveAmounts length"
        );
        ERC20 targetToken = ERC20(_token);
        //获得总计需要转账的金额,查看当前账号的限额是否足够,余额是否足够
        uint256 sumAmount = getSum(receiveAmounts);
        require(
            targetToken.allowance(msg.sender, address(this)) >= sumAmount,
            "allowance not enough"
        );
        require(
            targetToken.balanceOf(msg.sender) >= sumAmount,
            "balance not enough"
        );
        for (uint16 i = 0; i < receivers.length; i++) {
            targetToken.transferFrom(
                msg.sender,
                receivers[i],
                receiveAmounts[i]
            );
        }
    }

    /**
     * 批量转账给多个地址
     * @param receivers 收款人地址数组
     * @param receiveAmounts  收款人金额
     */
    function batchTransferETHToBatchAddress(
        address[] calldata receivers,
        uint256[] calldata receiveAmounts
    ) external payable returns (bool success) {
        require(
            receivers.length == receiveAmounts.length,
            "receivers length must equal receiveAmounts length"
        );
        uint256 sumAmount = getSum(receiveAmounts);
        require(msg.value == sumAmount, "balance not match");
        for (uint16 i = 0; i < receivers.length; i++) {
            (success, ) = payable(receivers[i]).call{value: receiveAmounts[i]}(
                ""
            );
        }
    }

    function getSum(
        uint256[] calldata amounts
    ) internal pure returns (uint256 sum) {
        for (uint16 i = 0; i < amounts.length; i++) {
            sum += amounts[i];
        }
        return sum;
    }
}
