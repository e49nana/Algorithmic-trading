// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title FirstContract - A simple wallet contract
/// @author Sola / AlgoSphere Quant
/// @notice Demonstrates core Solidity concepts: state, functions, modifiers, events, mappings

contract FirstContract {

    // --- State Variables ---
    address public owner;
    string public name;
    uint256 public totalDeposits;
    mapping(address => uint256) public balances;

    // --- Events ---
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event NameChanged(string oldName, string newName);

    // --- Modifiers ---
    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    modifier hasBalance(uint256 _amount) {
        require(balances[msg.sender] >= _amount, "Insufficient balance");
        _;
    }

    // --- Constructor ---
    constructor(string memory _name) {
        owner = msg.sender;
        name = _name;
    }

    // --- Functions ---

    /// @notice Deposit ETH into the contract
    function deposit() external payable {
        require(msg.value > 0, "Must send ETH");

        balances[msg.sender] += msg.value;
        totalDeposits += msg.value;

        emit Deposited(msg.sender, msg.value);
    }

    /// @notice Withdraw your deposited ETH
    function withdraw(uint256 _amount) external hasBalance(_amount) {
        balances[msg.sender] -= _amount;

        (bool success, ) = msg.sender.call{value: _amount}("");
        require(success, "Transfer failed");

        emit Withdrawn(msg.sender, _amount);
    }

    /// @notice Update the contract name (owner only)
    function setName(string memory _newName) external onlyOwner {
        string memory oldName = name;
        name = _newName;
        emit NameChanged(oldName, _newName);
    }

    /// @notice Check the contract's total ETH balance
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /// @notice Allow contract to receive ETH directly
    receive() external payable {
        balances[msg.sender] += msg.value;
        totalDeposits += msg.value;
        emit Deposited(msg.sender, msg.value);
    }
}
