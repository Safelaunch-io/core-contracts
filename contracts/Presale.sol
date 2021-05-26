// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract Presale is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public token;
    address public weiToken; // zero: buyWithEth, else: Token

    mapping(address => bool) public whitelistedAddresses;
    mapping(address => uint256) public weiLimits;

    uint256 public tokenTarget;
    uint256 public weiTarget;
    uint256 public multiplier;
    bool public isPublic;
    uint256 public startTime;
    uint256 public endTime;
    uint256 public claimTime;
    uint256 public minWei;
    uint256 public maxWei;

    uint256 public startLockDuration = 30 minutes;

    uint256 public totalOwed;
    mapping(address => uint256) public claimable;
    uint256 public weiRaised;

    event BasicDataChanged(
        uint256 tokenTarget,
        uint256 weiTarget,
        uint256 multiplier,
        uint256 minWei,
        uint256 maxWei,
        bool isPublic
    );

    event PresaleDataChanged(
        uint256 startTime,
        uint256 endTime,
        uint256 claimTime
    );

    event PresaleProgressChanged(uint256 totalOwed, uint256 weiRaised);

    constructor(
        IERC20 _token,
        uint256 _tokenTarget,
        address _weiToken,
        uint256 _weiTarget,
        uint256 _minWei,
        uint256 _maxWei,
        bool _isPublic
    ) {
        token = _token;
        tokenTarget = _tokenTarget;
        weiToken = _weiToken;
        weiTarget = _weiTarget;
        multiplier = tokenTarget.div(weiTarget);
        minWei = _minWei;
        maxWei = _maxWei;
        isPublic = _isPublic;

        emit BasicDataChanged(
            tokenTarget,
            weiTarget,
            multiplier,
            minWei,
            maxWei,
            isPublic
        );
    }

    function setPublic(bool _isPublic) external onlyOwner {
        require(
            startTime == 0 || block.timestamp > (startTime + startLockDuration),
            "You can't call this function now!"
        );
        isPublic = _isPublic;

        emit BasicDataChanged(
            tokenTarget,
            weiTarget,
            multiplier,
            minWei,
            maxWei,
            isPublic
        );
    }

    function setTokenTarget(uint256 _tokenTarget) external onlyOwner {
        require(
            startTime == 0 || block.timestamp < startTime,
            "Presale already started!"
        );
        tokenTarget = _tokenTarget;
        multiplier = tokenTarget.div(weiTarget);
        emit BasicDataChanged(
            tokenTarget,
            weiTarget,
            multiplier,
            minWei,
            maxWei,
            isPublic
        );
    }

    function setWeiTarget(uint256 _weiTarget) external onlyOwner {
        require(
            startTime == 0 || block.timestamp < startTime,
            "Presale already started!"
        );
        weiTarget = _weiTarget;
        multiplier = tokenTarget.div(weiTarget);
        emit BasicDataChanged(
            tokenTarget,
            weiTarget,
            multiplier,
            minWei,
            maxWei,
            isPublic
        );
    }

    function setStartTime(uint256 _startTime) external onlyOwner {
        require(
            startTime == 0 || block.timestamp < startTime,
            "Presale already started!"
        );
        require(block.timestamp < _startTime, "Can't set past time");
        startTime = _startTime;

        emit PresaleDataChanged(startTime, endTime, claimTime);
    }

    function setEndTime(uint256 _endTime) external onlyOwner {
        require(
            endTime == 0 || block.timestamp < endTime,
            "Presale already ended!"
        );
        require(block.timestamp < _endTime, "Can't set past time");
        endTime = _endTime;
        emit PresaleDataChanged(startTime, endTime, claimTime);
    }

    function setClaimTime(uint256 _claimTime) external onlyOwner {
        require(
            claimTime == 0 || block.timestamp < claimTime,
            "Claim already allowed!"
        );
        require(block.timestamp < _claimTime, "Can't set past time");
        claimTime = _claimTime;
        emit PresaleDataChanged(startTime, endTime, claimTime);
    }

    function setMinWei(uint256 _minWei) external onlyOwner {
        require(
            startTime > block.timestamp || startTime == 0,
            "Presale already started!"
        );
        minWei = _minWei;
        emit BasicDataChanged(
            tokenTarget,
            weiTarget,
            multiplier,
            minWei,
            maxWei,
            isPublic
        );
    }

    function setStartLockDuration(uint256 _startLockDuration)
        external
        onlyOwner
    {
        startLockDuration = _startLockDuration;
    }

    function setMaxWei(uint256 _maxWei) external onlyOwner {
        require(
            startTime > block.timestamp || startTime == 0,
            "Presale already started!"
        );
        maxWei = _maxWei;
        emit BasicDataChanged(
            tokenTarget,
            weiTarget,
            multiplier,
            minWei,
            maxWei,
            isPublic
        );
    }

    function addWhitelistedAddress(address _address, uint256 _weiLimit)
        external
        onlyOwner
    {
        require(_weiLimit > minWei, "WeiLimist should be greater than MinWei");
        whitelistedAddresses[_address] = true;
        weiLimits[_address] = _weiLimit;
    }

    function addMultipleWhitelistedAddresses(
        address[] calldata _addresses,
        uint256 _weiLimit
    ) external onlyOwner {
        require(_weiLimit > minWei, "WeiLimist should be greater than MinWei");
        for (uint256 i = 0; i < _addresses.length; i++) {
            whitelistedAddresses[_addresses[i]] = true;
            weiLimits[_addresses[i]] = _weiLimit;
        }
    }

    function removeWhitelistedAddress(address _address) external onlyOwner {
        whitelistedAddresses[_address] = false;
        weiLimits[_address] = 0;
    }

    function withdrawWei(uint256 amount) public onlyOwner {
        require(weiToken == address(0), "This is not eth-buy pool!");

        require(block.timestamp > endTime, "presale has not yet ended");
        msg.sender.transfer(amount);
    }

    function withdrawWeiToken(uint256 amount) public onlyOwner {
        require(weiToken != address(0), "This is not token-buy pool!");

        require(block.timestamp > endTime, "presale has not yet ended");
        IERC20(weiToken).transfer(msg.sender, amount);
    }

    function claimableAmount(address user) external view returns (uint256) {
        return claimable[user].mul(multiplier);
    }

    function withdrawToken() external onlyOwner {
        require(block.timestamp > endTime, "presale has not yet ended");
        token.transfer(
            msg.sender,
            token.balanceOf(address(this)).sub(totalOwed)
        );
    }

    function claim() external {
        require(
            block.timestamp > claimTime && claimTime != 0,
            "claiming not allowed yet"
        );
        require(claimable[msg.sender] > 0, "nothing to claim");

        uint256 amount = claimable[msg.sender].mul(multiplier);

        claimable[msg.sender] = 0;
        totalOwed = totalOwed.sub(amount);

        require(token.transfer(msg.sender, amount), "failed to claim");
    }

    function checkBeforeBuy() internal {
        require(
            startTime != 0 && block.timestamp > startTime,
            "presale has not yet started"
        );
        require(
            endTime != 0 && block.timestamp < endTime,
            "presale already ended"
        );
        if (isPublic == false) {
            require(
                whitelistedAddresses[msg.sender] == true,
                "you are not whitelisted"
            );
        }
    }

    function buy(uint256 value) external {
        require(weiToken != address(0), "This is not token-buy pool!");

        checkBeforeBuy();

        require(value >= minWei, "amount too low");
        require(weiRaised.add(value) <= weiTarget, "target already hit");

        uint256 amount = value.mul(multiplier);
        require(
            totalOwed.add(amount) <= token.balanceOf(address(this)),
            "sold out"
        );
        if (isPublic) {
            require(
                claimable[msg.sender].add(value) <= maxWei,
                "maximum purchase cap hit"
            );
        } else {
            require(
                claimable[msg.sender].add(value) <= weiLimits[msg.sender],
                "maximum purchase cap hit"
            );
        }

        claimable[msg.sender] = claimable[msg.sender].add(value);
        totalOwed = totalOwed.add(amount);
        weiRaised = weiRaised.add(value);

        IERC20(weiToken).transferFrom(msg.sender, address(this), value);

        emit PresaleProgressChanged(totalOwed, weiRaised);
    }

    function buyWithEth() public payable {
        require(weiToken == address(0), "This is not eth-buy pool!");

        checkBeforeBuy();

        require(msg.value >= minWei, "amount too low");
        require(weiRaised.add(msg.value) <= weiTarget, "target already hit");

        uint256 amount = msg.value.mul(multiplier);
        require(
            totalOwed.add(amount) <= token.balanceOf(address(this)),
            "sold out"
        );
        if (isPublic) {
            require(
                claimable[msg.sender].add(msg.value) <= maxWei,
                "maximum purchase cap hit"
            );
        } else {
            require(
                claimable[msg.sender].add(msg.value) <= weiLimits[msg.sender],
                "maximum purchase cap hit"
            );
        }

        claimable[msg.sender] = claimable[msg.sender].add(msg.value);
        totalOwed = totalOwed.add(amount);
        weiRaised = weiRaised.add(msg.value);

        emit PresaleProgressChanged(totalOwed, weiRaised);
    }

    fallback() external payable {
        buyWithEth();
    }

    receive() external payable {
        buyWithEth();
    }
}
