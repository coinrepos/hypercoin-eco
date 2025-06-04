// SPDX-License-Identifier: No Licence
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract HyperCoinEcosystem is ERC20, Pausable, Ownable {
    uint256 public inTax; // Percentage (e.g. 5 = 5%)
    address[] public liquidityPools;

    struct Proposal {
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        mapping(address => bool) hasVoted;
        bool executed;
    }

    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCount;

    mapping(address => uint256) public earnings;
    uint256 public totalSpent;
    mapping(address => uint256) public spending;

    mapping(address => bool) public authorizedSlotGames;

    constructor() ERC20("HyperCoin", "HYPE") {
        _mint(msg.sender, 1_000_000_000 * 1e18);
    }

    // ----- InTax Control -----
    function setInTax(uint256 _percentage) external onlyOwner {
        require(_percentage <= 20, "Too high");
        inTax = _percentage;
    }

    function getInTax() external view returns (uint256) {
        return inTax;
    }

    // ----- Mint / Burn -----
    function mint(uint256 amount) external onlyOwner {
        _mint(owner(), amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    // ----- Pause Control -----
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // ----- DAO Governance -----
    function propose(string memory description) external returns (uint256) {
        proposalCount++;
        proposals[proposalCount].description = description;
        return proposalCount;
    }

    function vote(uint256 proposalId, bool support) external {
        Proposal storage p = proposals[proposalId];
        require(!p.executed, "Already executed");
        require(!p.hasVoted[msg.sender], "Already voted");
        p.hasVoted[msg.sender] = true;

        uint256 weight = balanceOf(msg.sender);
        if (support) {
            p.votesFor += weight;
        } else {
            p.votesAgainst += weight;
        }
    }

    function executeProposal(uint256 proposalId) external onlyOwner {
        Proposal storage p = proposals[proposalId];
        require(!p.executed, "Already executed");
        require(p.votesFor > p.votesAgainst, "Not enough support");
        p.executed = true;
    }

    function getProposal(uint256 id) external view returns (
        string memory desc,
        uint256 forVotes,
        uint256 againstVotes
    ) {
        Proposal storage p = proposals[id];
        return (p.description, p.votesFor, p.votesAgainst);
    }

    // ----- Earnings Routing -----
    function routeEarnings() external onlyOwner {
        for (uint256 i = 0; i < liquidityPools.length; i++) {
            address lp = liquidityPools[i];
            uint256 bal = balanceOf(lp);
            earnings[lp] += bal / 10; // example logic
        }
    }

    function getEarningsBalance(address user) external view returns (uint256) {
        return earnings[user];
    }

    function withdrawEarnings() external {
        uint256 amt = earnings[msg.sender];
        require(amt > 0, "Nothing to withdraw");
        earnings[msg.sender] = 0;
        _transfer(owner(), msg.sender, amt);
    }

    // ----- LP Management -----
    function setLiquidityPool(address lp) external onlyOwner {
        liquidityPools.push(lp);
    }

    function getLiquidityPools() external view returns (address[] memory) {
        return liquidityPools;
    }

    // ----- Wrapped Token Logic (Simulated) -----
    function wrap(uint256 amount) external {
        _burn(msg.sender, amount);
        // Assume interaction with external wrapper
    }

    function unwrap(uint256 amount) external {
        _mint(msg.sender, amount);
        // Assume interaction with external unwrapper
    }

    // ----- Analytics -----
    function getSpendingStats() external view returns (uint256, uint256) {
        return (totalSpent, totalSupply() / 1e18);
    }

    function getHolderData(address user) external view returns (uint256, uint256) {
        return (balanceOf(user), earnings[user]);
    }

    // ----- Slot/Casino Game Hooks -----
    function authorizeSlotGame(address game) external onlyOwner {
        authorizedSlotGames[game] = true;
    }

    function slotGameRevenue(address game, uint256 amount) external {
        require(authorizedSlotGames[game], "Not authorized");
        _mint(owner(), amount); // Example: reward to ecosystem treasury
    }

    // ----- Transfer Override: InTax -----
    function _transfer(address from, address to, uint256 amount) internal override whenNotPaused {
        if (from != owner() && inTax > 0) {
            uint256 tax = (amount * inTax) / 100;
            uint256 sendAmount = amount - tax;
            super._transfer(from, address(this), tax);
            super._transfer(from, to, sendAmount);
            totalSpent += sendAmount;
            spending[from] += sendAmount;
        } else {
            super._transfer(from, to, amount);
        }
    }
}
