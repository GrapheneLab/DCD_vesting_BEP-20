// SPDX-License-Identifier: MIT
pragma solidity 0.8.8;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract Vesting is Ownable {
    struct Category {
        uint256 lockPeriod;
        uint256 period;
        uint256 timeUnit;
        uint256 afterUnlock;
        uint256 afterUnlockDenominator;
    }

    uint256 constant MONTH = 30 days;

    IERC20 token;

    uint256 public startTimestamp;

    mapping(string => Category) public categories;
    mapping(address => mapping(string => uint256)) public allocations;
    mapping(address => uint256) public earned;

    event Claimed(uint256 indexed timestamp, address indexed user, uint256 amount);

    constructor(address tokenAddress, address owner) {
        // setup defaults
        token = IERC20(tokenAddress);
        transferOwnership(owner);

        // setup Categories
        categories['team'] = Category({
            lockPeriod: 6 * MONTH,
            period: 31 * MONTH,
            timeUnit: MONTH,
            afterUnlock: 0,
            afterUnlockDenominator: 100
        });
        categories['marketing'] = Category({
            lockPeriod: 0,
            period: 8 * MONTH,
            timeUnit: MONTH,
            afterUnlock: 0,
            afterUnlockDenominator: 100
        });
        categories['seed'] = Category({
            lockPeriod: 0,
            period: 15 * MONTH,
            timeUnit: MONTH,
            afterUnlock: 10,
            afterUnlockDenominator: 100
        });
        categories['strategic'] = Category({
            lockPeriod: 0,
            period: 12 * MONTH,
            timeUnit: MONTH,
            afterUnlock: 10,
            afterUnlockDenominator: 100
        });
        categories['presale'] = Category({
            lockPeriod: 0,
            period: 5 * MONTH,
            timeUnit: MONTH,
            afterUnlock: 30,
            afterUnlockDenominator: 100
        });
        categories['public'] = Category({
            lockPeriod: 0,
            period: 2 * MONTH,
            timeUnit: 1 weeks,
            afterUnlock: 30,
            afterUnlockDenominator: 100
        });
        categories['game'] = Category({
            lockPeriod: 10 days,
            period: 38 * MONTH,
            timeUnit: MONTH,
            afterUnlock: 5,
            afterUnlockDenominator: 100
        });
        categories['eco'] = Category({
            lockPeriod: 3 * MONTH,
            period: 43 * MONTH,
            timeUnit: MONTH,
            afterUnlock: 0,
            afterUnlockDenominator: 100
        });
        categories['community'] = Category({
            lockPeriod: 0,
            period: 37 * MONTH,
            timeUnit: MONTH,
            afterUnlock: 0,
            afterUnlockDenominator: 100
        });
    }

    /// @dev starts claim for users
    function start() public onlyOwner isNotStarted {
        startTimestamp = block.timestamp;
    }

    /// @dev let users to claim their tokens from start to last claim
    function claim() public isStarted {
        uint256 claimed_ = claimed(msg.sender);
        require(claimed_ > 0, 'You dont have tokens now');
        require(
            token.balanceOf(address(this)) > claimed_,
            'Vesting contract doesnt have enough tokens'
        );
        earned[msg.sender] += claimed_;
        token.transfer(msg.sender, claimed_);

        emit Claimed(block.timestamp, msg.sender, claimed_);
    }

    /// @dev calculates claimed amount for user
    function claimed(address user) public view isStarted returns (uint256 amount) {
        uint256 total = claimedInCategory(user, 'team') +
            claimedInCategory(user, 'marketing') +
            claimedInCategory(user, 'seed') +
            claimedInCategory(user, 'strategic') +
            claimedInCategory(user, 'presale') +
            claimedInCategory(user, 'public') +
            claimedInCategory(user, 'game') +
            claimedInCategory(user, 'eco') +
            claimedInCategory(user, 'community') -
            earned[user];
        return total;
    }

    /// @dev calculates for category
    function claimedInCategory(address user, string memory categoryName)
        public
        view
        isStarted
        returns (uint256 amount)
    {
        Category memory category = categories[categoryName];
        uint256 vestingTime = block.timestamp - startTimestamp;

        // before lock period
        if (category.lockPeriod >= vestingTime) return 0;

        // after lock period
        uint256 bank = allocations[user][categoryName];
        uint256 amountOnUnlock = (bank * category.afterUnlock) / category.afterUnlockDenominator;

        uint256 timePassed = vestingTime - category.lockPeriod;
        uint256 totalUnits = (category.period - category.lockPeriod) / category.timeUnit;
        uint256 amountOfUnits = timePassed / category.timeUnit;
        uint256 amountAfterUnlock = ((bank - amountOnUnlock) * amountOfUnits) / totalUnits;

        return amountOnUnlock + amountAfterUnlock;
    }

    function setupWallets(
        string memory category,
        address[] memory users,
        uint256[] memory allocations_
    ) external onlyOwner isNotStarted {
        require(users.length == allocations_.length, 'Wrong inputs');
        uint256 length = users.length;
        for (uint256 i = 0; i < length; i++) {
            allocations[users[i]][category] = allocations_[i];
        }
    }

    /// @dev Throws if called before start.
    modifier isStarted() {
        require(startTimestamp != 0, 'Vesting have not started yet');
        _;
    }

    /// @dev Throws if called after start.
    modifier isNotStarted() {
        require(startTimestamp == 0, 'Vesting have already started');
        _;
    }
}
