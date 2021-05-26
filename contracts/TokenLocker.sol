// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenLocker is Ownable {
    using SafeMath for uint256;
    using Address for address;

    struct LockInfo {
        address beneficiary;
        uint256 duration;
        uint256 cliff;
        uint256 amount;
        uint256 startTime;
        uint256 released;
    }

    event TokenLocked(
        address beneficiary,
        uint256 duration,
        uint256 cliff,
        uint256 amount,
        uint256 startTime,
        uint256 lockId
    );

    event TokenReleased(address beneficiary, uint256 amount, uint256 lockId);

    IERC20 public token;

    uint256 public lockCount;
    LockInfo[] public lockInfos;
    mapping(address => uint256[]) public lockIds;

    constructor(IERC20 _token) {
        require(address(_token) != address(0), "Token address can't be zero!");
        token = _token;
    }

    function getAvilableAmount(uint256 lockId) public view returns (uint256) {
        uint256 amount = lockInfos[lockId].amount;
        uint256 cliff = lockInfos[lockId].cliff;
        uint256 startTime = lockInfos[lockId].startTime;
        uint256 duration = lockInfos[lockId].duration;
        uint256 released = lockInfos[lockId].released;
        uint256 finalTime = startTime.add(duration);
        if (finalTime < block.timestamp) {
            return amount.sub(released);
        } else if (startTime > block.timestamp) {
            return uint256(0);
        } else {
            uint256 totalCliffs = duration.div(cliff);
            uint256 cliffAmount = amount.div(totalCliffs);
            uint256 currentCliffCount =
                (block.timestamp - startTime).div(cliff);
            uint256 availableAmount = cliffAmount.mul(currentCliffCount);
            return availableAmount.sub(released);
        }
    }

    function getLockIds(address beneficiary)
        external
        view
        returns (uint256[] memory)
    {
        return lockIds[beneficiary];
    }

    function getReleasableAmount(address beneficiary)
        external
        view
        returns (uint256)
    {
        uint256 available = uint256(0);
        uint256 length = lockIds[beneficiary].length;
        require(length > 0, "No locked token for this address");
        for (uint256 index = 0; index < length; ++index) {
            uint256 subAvailable =
                getAvilableAmount(lockIds[beneficiary][index]);
            available = available.add(subAvailable);
        }
        return available;
    }

    function releaseTokenFromLockPool(uint256 lockId) external {
        require(
            lockInfos[lockId].beneficiary == msg.sender,
            "You are not beneficiary account"
        );
        uint256 availableAmount = getAvilableAmount(lockId);
        require(
            availableAmount > 0,
            "You don't have any releasable amount yet"
        );
        emit TokenReleased(msg.sender, availableAmount, lockId);
        token.transfer(msg.sender, availableAmount);
        lockInfos[lockId].released = lockInfos[lockId].released.add(
            availableAmount
        );
    }

    function releaseAllAvailableTokens() external {
        uint256 available = uint256(0);
        uint256 length = lockIds[msg.sender].length;
        require(length > 0, "You don't have any locked token to release");
        for (uint256 index = 0; index < length; ++index) {
            uint256 lockId = lockIds[msg.sender][index];
            uint256 subAvailable = getAvilableAmount(lockId);
            available = available.add(subAvailable);
            lockInfos[lockId].released = lockInfos[lockId].released.add(
                subAvailable
            );
            emit TokenReleased(msg.sender, subAvailable, lockId);
        }
        require(available > 0, "You don't have any releasable amount yet");
        token.transfer(msg.sender, available);
    }

    function lockTokens(
        address beneficiary,
        uint256 duration,
        uint256 cliff,
        uint256 amount,
        uint256 startTime
    ) external onlyOwner {
        require(
            startTime > block.timestamp,
            "StartTime should be greater than current time"
        );
        require(cliff > 0, "Cliff should be greater than zero");
        require(duration >= cliff, "Duration should be greater than Cliff");
        require(
            duration.sub(duration.div(cliff).mul(cliff)) == 0,
            "Duration should be divided by cliff completely"
        );
        require(amount > 0, "Amount should be greater than zero");
        require(beneficiary != address(0), "Beneficiary can't be zero address");
        uint256 infoLength = lockInfos.length;
        lockInfos.push(
            LockInfo({
                beneficiary: beneficiary,
                duration: duration,
                cliff: cliff,
                amount: amount,
                startTime: startTime,
                released: uint256(0)
            })
        );
        lockIds[beneficiary].push(infoLength);
        lockCount = lockCount + 1;

        emit TokenLocked(
            beneficiary,
            duration,
            cliff,
            amount,
            startTime,
            infoLength
        );
        token.transferFrom(msg.sender, address(this), amount);
    }
}
