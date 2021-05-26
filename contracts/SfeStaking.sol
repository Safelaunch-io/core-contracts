// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SfeStaking is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 pendingRewards;
        uint256 lastClaim;
    }

    struct PoolInfo {
        uint256 allocPoint;
        uint256 lastRewardBlock;
        uint256 accSfePerShare;
        uint256 depositedAmount;
        uint256 rewardsAmount;
        uint256 lockupDuration;
    }

    IERC20 public sfe;
    uint256 public sfePerBlock = 1 ether; // 1 sfe

    PoolInfo[] public poolInfo;
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    uint256 public totalAllocPoint = 446;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event Claim(address indexed user, uint256 indexed pid, uint256 amount);

    function addPool(uint256 _allocPoint, uint256 _lockupDuration) internal {
        poolInfo.push(
            PoolInfo({
                allocPoint: _allocPoint,
                lastRewardBlock: 0,
                accSfePerShare: 0,
                depositedAmount: 0,
                rewardsAmount: 0,
                lockupDuration: _lockupDuration
            })
        );
    }

    function setSfeToken(IERC20 _sfe) external onlyOwner {
        require(address(sfe) == address(0), "Token already set!");
        sfe = _sfe;

        addPool(100, 7 days); // 10% staking
        addPool(346, 30 days); // 34.6% staking
    }

    function startStaking(uint256 startBlock) external onlyOwner {
        require(
            poolInfo[0].lastRewardBlock == 0 &&
                poolInfo[1].lastRewardBlock == 0,
            "Staking already started"
        );
        poolInfo[0].lastRewardBlock = startBlock;
        poolInfo[1].lastRewardBlock = startBlock;
    }

    function setLockupDuration(uint256 _lockupDuration, uint256 pid)
        external
        onlyOwner
    {
        PoolInfo storage pool = poolInfo[pid];
        pool.lockupDuration = _lockupDuration;
    }

    function pendingRewards(uint256 pid, address _user)
        external
        view
        returns (uint256)
    {
        require(
            poolInfo[pid].lastRewardBlock > 0 &&
                block.number >= poolInfo[pid].lastRewardBlock,
            "Staking not yet started"
        );
        PoolInfo storage pool = poolInfo[pid];
        UserInfo storage user = userInfo[pid][_user];
        uint256 accSfePerShare = pool.accSfePerShare;
        uint256 depositedAmount = pool.depositedAmount;
        if (block.number > pool.lastRewardBlock && depositedAmount != 0) {
            uint256 multiplier = block.number.sub(pool.lastRewardBlock);
            uint256 sfeReward =
                multiplier.mul(sfePerBlock).mul(pool.allocPoint).div(
                    totalAllocPoint
                );
            accSfePerShare = accSfePerShare.add(
                sfeReward.mul(1e12).div(depositedAmount)
            );
        }
        return
            user.amount.mul(accSfePerShare).div(1e12).sub(user.rewardDebt).add(
                user.pendingRewards
            );
    }

    function updatePool(uint256 pid) internal {
        require(
            poolInfo[pid].lastRewardBlock > 0 &&
                block.number >= poolInfo[pid].lastRewardBlock,
            "Staking not yet started"
        );
        PoolInfo storage pool = poolInfo[pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 depositedAmount = pool.depositedAmount;
        if (pool.depositedAmount == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = block.number.sub(pool.lastRewardBlock);
        uint256 sfeReward =
            multiplier.mul(sfePerBlock).mul(pool.allocPoint).div(
                totalAllocPoint
            );
        pool.rewardsAmount = pool.rewardsAmount.add(sfeReward);
        pool.accSfePerShare = pool.accSfePerShare.add(
            sfeReward.mul(1e12).div(depositedAmount)
        );
        pool.lastRewardBlock = block.number;
    }

    function deposit(uint256 pid, uint256 amount) external {
        PoolInfo storage pool = poolInfo[pid];
        UserInfo storage user = userInfo[pid][msg.sender];
        updatePool(pid);
        if (user.amount > 0) {
            uint256 pending =
                user.amount.mul(pool.accSfePerShare).div(1e12).sub(
                    user.rewardDebt
                );
            if (pending > 0) {
                user.pendingRewards = user.pendingRewards.add(pending);
            }
        }
        if (amount > 0) {
            sfe.safeTransferFrom(address(msg.sender), address(this), amount);
            user.amount = user.amount.add(amount);
            pool.depositedAmount = pool.depositedAmount.add(amount);
        }
        user.rewardDebt = user.amount.mul(pool.accSfePerShare).div(1e12);
        user.lastClaim = block.timestamp;
        emit Deposit(msg.sender, pid, amount);
    }

    function withdraw(uint256 pid, uint256 amount) external {
        PoolInfo storage pool = poolInfo[pid];
        UserInfo storage user = userInfo[pid][msg.sender];
        require(
            block.timestamp > user.lastClaim + pool.lockupDuration,
            "You cannot withdraw yet!"
        );
        require(user.amount >= amount, "Withdrawing more than you have!");
        updatePool(pid);
        uint256 pending =
            user.amount.mul(pool.accSfePerShare).div(1e12).sub(user.rewardDebt);
        if (pending > 0) {
            user.pendingRewards = user.pendingRewards.add(pending);
        }
        if (amount > 0) {
            sfe.safeTransfer(address(msg.sender), amount);
            user.amount = user.amount.sub(amount);
            pool.depositedAmount = pool.depositedAmount.sub(amount);
        }
        user.rewardDebt = user.amount.mul(pool.accSfePerShare).div(1e12);
        user.lastClaim = block.timestamp;
        emit Withdraw(msg.sender, pid, amount);
    }

    function claim(uint256 pid) public {
        PoolInfo storage pool = poolInfo[pid];
        UserInfo storage user = userInfo[pid][msg.sender];
        updatePool(pid);
        uint256 pending =
            user.amount.mul(pool.accSfePerShare).div(1e12).sub(user.rewardDebt);
        if (pending > 0 || user.pendingRewards > 0) {
            user.pendingRewards = user.pendingRewards.add(pending);
            uint256 claimedAmount =
                safeSfeTransfer(msg.sender, user.pendingRewards, pid);
            emit Claim(msg.sender, pid, claimedAmount);
            user.pendingRewards = user.pendingRewards.sub(claimedAmount);
            user.lastClaim = block.timestamp;
            pool.rewardsAmount = pool.rewardsAmount.sub(claimedAmount);
        }
        user.rewardDebt = user.amount.mul(pool.accSfePerShare).div(1e12);
    }

    function safeSfeTransfer(
        address to,
        uint256 amount,
        uint256 pid
    ) internal returns (uint256) {
        PoolInfo memory pool = poolInfo[pid];
        if (amount > pool.rewardsAmount) {
            sfe.safeTransfer(to, pool.rewardsAmount);
            return pool.rewardsAmount;
        } else {
            sfe.safeTransfer(to, amount);
            return amount;
        }
    }

    function setSfePerBlock(uint256 _sfePerBlock) external onlyOwner {
        require(_sfePerBlock > 0, "SFE per block should be greater than 0!");
        sfePerBlock = _sfePerBlock;
    }
}
