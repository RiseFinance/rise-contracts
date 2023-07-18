// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./common/Context.sol";
import "./interfaces/IL3Vault.sol";
import {ArbSys} from "./interfaces/ArbSys.sol";

contract L3Gateway_old is Context {
    // FIXME: token trasfers from L3Vault to L3Gateway should be done by L3Vault
    IL3Vault public l3Vault;

    mapping(uint256 => uint256) public balancesTracker; // assetId => balance; only used in _depositInAmount

    constructor(address _l3Vault) {
        l3Vault = IL3Vault(_l3Vault);
    }

    // for ERC-20
    /**
    function _depositInAmount(address _token) private returns (uint256) {
        uint256 prevBalance = balancesTracker[_token];
        uint256 currentBalance = IERC20(_token).balanceOf(address(this)); // L3Vault balance
        balancesTracker[_token] = currentBalance;

        return currentBalance.sub(prevBalance); // L3Vault balance delta
    } */

    // for ETH
    function _depositInAmountEth() private returns (uint256) {
        uint256 prevBalance = balancesTracker[ETH_ID]; // allocate ETH to address(0)
        uint256 currentBalance = address(this).balance; // L3Vault balance
        balancesTracker[ETH_ID] = currentBalance;

        // return currentBalance.sub(prevBalance); // L3Vault balance delta // TODO: SafeMath
        return currentBalance - prevBalance; // L3Vault balance delta
    }

    /**
     * @notice
     * to be deprecated
     *
     * @dev
     * direct ETH deposit from L3 account to the L3Vault
     */
    function depositEth() external payable {
        require(msg.value > 0, "L3Gateway: deposit amount should be positive");
        l3Vault.increaseTraderBalance(msg.sender, ETH_ID, msg.value);
    }

    /**
     * @notice
     * L3 traders account should never hold ETH or ERC-20 tokens directly
     * (only system call allowed)
     *
     * @dev
     * from: Nitro / to: L3Vault
     * nitro Node calls this function when it receives a message from L2 Inbox
     * this function is part of the auto redemption process of L2->L3 ETH deposit in ArbOS
     * transfers ETH from the L2 trader's account to the L3Vault and updates traderBalances
     */
    function depositEthFromL2(address depositor) external payable {
        // check - additional security check: msg.sender == L2Gateway (or OnlyNitro)
        // check - additional vlaidation: msg.value == original deposit amount from L2
        require(msg.value > 0, "L3Gateway: deposit amount should be positive");
        uint256 depositIn = _depositInAmountEth();

        require(
            depositIn == msg.value,
            "L3Gateway: depositIn amount must be equal to msg.value"
        );

        l3Vault.increaseTraderBalance(depositor, ETH_ID, depositIn);
    }

    /**
     * @notice to be deprecated
     */
    function withdrawEth(uint256 amount) external {
        uint256 balance = l3Vault.getTraderBalance(msg.sender, ETH_ID);
        require(balance >= amount, "L3Gateway: insufficient balance");
        l3Vault.decreaseTraderBalance(msg.sender, ETH_ID, amount);

        payable(msg.sender).transfer(amount);
    }

    /**
     * @dev
     * from: trader / to: L3 ArbSys
     * check: `from` address to be L3Vault or the trader?
     * subtracts the amount from the trader's balance and sends the amount to the L2 trader's account through ArbSys.withdrawEth
     * nitro node should create a ticket on L2 so that the trader can withdraw the ETH from L2 with Merkle proof after the L3 block is confirmed.
     *
     * no need to change nitro codebase for Outbox
     */
    function withdrawEthToL2(uint256 amount) external {
        uint256 balance = l3Vault.getTraderBalance(msg.sender, ETH_ID);

        require(balance >= amount, "L3Gateway: insufficient balance");
        l3Vault.decreaseTraderBalance(msg.sender, ETH_ID, amount);

        // If it is possible to set `from` address to L3Vault, then the following code works.
        // If not, L3Vault should send ETH to the trader and then the trader sends ETH to ArbSys.

        // send ETH to the trader from L3Vault
        // (bool sent, bytes memory data) = msg.sender.call{value: amount}("");
        // require(sent, "Failed to send Ether");
        ArbSys(address(100)).withdrawEth{value: amount}(msg.sender); // precompile address 0x0000000000000000000000000000000000000064
        // check: msg.sender or tx.origin?
    }
}
