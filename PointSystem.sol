//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * 
 * @title 
 * @author lrqstudy
 * @notice lrqstudy@gmail.com
 * 
 */
contract PointSystem {
    
    address public owner;
    //default 0.1eth
    uint256 public registerFee = 10 ** 17;
    //swap rate
    uint256 public pointsRate = 10000;
    //refer reward
    uint256 public referralReward = 2 * 10 ** 16;
    string public projectName;

    mapping(address => address) public referralMap;

    /**
     * 
     * @param spender spender
     * @param value value
     */
    event Charge(address indexed spender, uint256 value);

    /**
     * event
     * @param owner owner
     * @param fee fee
     * @param rate rate
     */
    event SetParameter(
        address indexed owner,
        uint256 fee,
        uint256 rate,
        uint256 referral_reward
    );

    event UsePoints(address indexed spender, uint256 points);

    constructor(string memory _projectName,address _owner) {
        projectName = _projectName;
        owner = _owner;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "only owner");
        _;
    }

    mapping(address => uint256) public points;

    /**
     * set referral
     * @param userId userid
     * @param referral referral
     */
    function setReferral(address userId,address referral) public onlyOwner {
        referralMap[userId] = referral;
    }

    /**
     * set parameter
     * @param fee fee
     * @param rate rate
     * @param referral_reward reward
     */
    function setParameter(
        uint256 fee,
        uint256 rate,
        uint256 referral_reward
    ) public onlyOwner {
        require(fee > 0 && rate >0, "fee must > 0");
        require(referral_reward < fee, "referral_reward must < fee");
        registerFee = fee;
        pointsRate = rate;
        referralReward = referral_reward;
        emit SetParameter(msg.sender, fee, rate, referral_reward);
    }

    /**
     * get points
     * @param addr addresss
     */
    function getPoints(address addr) public view returns (uint256) {
        return points[addr];
    }

    /**
     * use points
     * @param point point
     */
    function usePoints(uint256 point) public {
        require(points[msg.sender] >= point, "points not enough");
        points[msg.sender] -= point;
        emit UsePoints(msg.sender, point);
    }

    /**
     * charge points
     * @param referral referral
     */
    function chargePoints(address referral) public payable returns(bool success) {
        require(msg.value >= registerFee, "at least 0.1 eth");
        referralMap[msg.sender] = referral;
        uint256 point = (msg.value / registerFee) * pointsRate;
        points[msg.sender] += point;
        if (referral == msg.sender) {
            (success, ) = payable(owner).call{value: msg.value}("");
            emit Charge(msg.sender, msg.value);
            return true ;
        }
        (success, ) = payable(referral).call{value: referralReward}("");
        uint256 owner_amount = msg.value - referralReward;
        (success, ) = payable(owner).call{value: owner_amount}("");
        emit Charge(msg.sender, msg.value);
        return success;
    }

    receive() external payable {
        require(msg.value >= registerFee, "at least 0.1 eth");
        address referral = referralMap[msg.sender];
        if (referral == address(0)) {
            //default referral is himself
            referral = msg.sender;
        }
        chargePoints(referral);
    }
}

contract ContractFactory {

    function createPointSystem(string memory project_name) public returns (address) {
        return address(new PointSystem(project_name,msg.sender));
    }
}

