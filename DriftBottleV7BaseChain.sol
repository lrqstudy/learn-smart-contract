//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 *
 * 前端根据最大最小id进行随机获取
 * 使用自增id
 *
 * 必须去mint 一个nft,才有资格注册.
 *
 * @dev lrqstudy
 *
 */

contract DriftBottleV7BaseChain {
    //合约的owner
    address public owner;

    /**
     * @dev erc20
     */
    ERC20 internal constant supportingToken =
        ERC20(address(0xd3568579C93f9FB1cF8316b2A9485738B642953e));
    
    ERC721 internal constant supportingNFT =
        ERC721(address(0x5e4FB0e4CFEA85757964A465B293a927FB53d89D));



   

    /**
     * 用户信息mapping
     */
    mapping(address => UserInfo) private userInfos;

    /**
     * 用户是否存在mapping
     */
    mapping(address => bool) private userExists;

    /**
     * 漂流瓶mapping
     */
    mapping(uint256 => Bottle) private bottles;

    /**
     * @dev 奖励积分
     */
    mapping(address => uint256) public points;

    using Counters for Counters.Counter;
    /**
     * 漂流瓶自增id对象
     */
    Counters.Counter private bottleIds;

    /// 注册花费
    uint256 public registerFee = 200 * (10 ** 18);

    /// 捡瓶子花费
    uint256 public catchFee = 50 * (10 ** 18);

    // 丢瓶子花费
    uint256 public throwFee = 10 * (10 ** 18);

    //eth 换 token的比例,如1000 则代表 1Eth = 1000 token
    uint256 public swapRate = 1000;

    //捡瓶子平台抽取数量，剩余数量归丢瓶子
    uint256 public chargeFee = 5 * (10 ** 18);

    constructor() payable {
        bottleIds.increment();
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    /*
    定义一个修饰符，用于校验各个操作需要的费用
    */
    modifier operationFeeCheck(uint256 operationFee, uint256 amount) {
        require(amount >= operationFee, " less than operationFee ");
        _;
    }

    modifier nftHolding() {
        require(supportingNFT.balanceOf(msg.sender) > 0, "must hold nft");
        _;
    }

    /*
    定义一个校验修饰符,用于校验操作对象当前token的余额是否足够
    */
    modifier balanceCheck(uint256 amount) {
        require(
            supportingToken.balanceOf(msg.sender) >= amount,
            "balance not enough"
        );
        _;
    }

    /*
    定义了一个用户必须注册修饰符
     */
    modifier userExist() {
        require(userExists[msg.sender], " user must exist");
        _;
    }

    /**
     * 定义注册事件
     * @param userId 用户id
     * @param amount 金额
     */
    event Register(address indexed userId, uint256 amount);

    /**
     * 定义丢瓶子事件
     * @param userId 用户id
     * @param amount 金额
     */
    event ThrowBottle(
        address indexed userId,
        uint256 currentBottleId,
        uint256 amount
    );


    /**
     * 定义加入ICO事件
     * @param userId 用户地址
     * @param amount 金额
     */
    event JoinICO(address indexed userId, uint256 amount);

    /*
    定义了一个瓶子不存在的错误
    */
    error BottleNotExist(uint256 _bottleId);

    /*
    定义了一个打开了自己的瓶子错误
     */
    error OpenYourselfBotterError(uint256 _bottleId);

    /**
     * 捡瓶子事件
     * @param openor 打开瓶子的人
     * @param creator 瓶子的创建人
     * @param bottleId 瓶子id
     * @param greetings 祝福语
     * @param wechat 微信号
     * @param amount 金额
     */
    event CatchBottle(
        address indexed openor,
        address indexed creator,
        uint256 indexed bottleId,
        string greetings,
        string wechat,
        uint256 amount
    );

    /**
     * 参数设定
     * @param owner owner地址
     * @param registerFee 注册费
     * @param throwFee 丢瓶子费用
     * @param catchFee 捡瓶子费用
     * @param swapRate 兑换比例
     */
    event ParameterChanged(
        address indexed owner,
        uint256 registerFee,
        uint256 throwFee,
        uint256 catchFee,
        uint256 swapRate,
        uint256 chargeFee
    );

    /**
     * Swap事件
     * @param userId 用户地址
     * @param amount 金额
     */
    event Swap(address indexed userId, uint256 amount);

    /**
     * 提现eth事件
     * @param owner owner
     * @param amount 提现金额
     */
    event WithdrawETH(address indexed owner, uint256 amount);

    /**
     * 提现token事件
     * @param owner owner
     * @param amount 提现金额
     */
    event WithdrawToken(address indexed owner, uint256 amount);

    /**
     * 定义一个用户结构
     */
    struct UserInfo {
        address userId;
        string name;
        uint8 gender;
        uint8 age;
        string wechat;
    }
    /**
     * 定义一个漂流瓶结构
     */
    struct Bottle {
        uint256 bottleId;
        address userId;
        string greetings;
        string wechat;
    }
    

    /**
     * 用户注册函数
     * @param name 用户名
     * @param gender 性别1=男，2=女
     * @param age 年龄
     * @param wechat 微信
     * @param amount 金额
     */
    function regisger(
        string memory name,
        uint8 gender,
        uint8 age,
        string memory wechat,
        uint256 amount
    )
        external
        nftHolding
        operationFeeCheck(registerFee, amount)
        balanceCheck(amount)
        returns (bool)
    {
        //require(!userExists[msg.sender], "user exists");//判断用户不存在继续执行后续逻辑
        require(age > 0, "age must positive");
        require(gender == 1 || gender == 2, " gender must be 1 or 2");
        require(bytes(name).length > 0, "name cannot empty");
        require(
            bytes(wechat).length >= 8 && bytes(wechat).length <= 28,
            "wechat length must be 8 to 28"
        ); //微信号只能是8-28位
        supportingToken.transferFrom(msg.sender, address(this), amount);
        //标记用户已经存在
        userExists[msg.sender] = true;
        userInfos[msg.sender] = UserInfo({
            userId: msg.sender,
            name: name,
            gender: gender,
            age: age,
            wechat: wechat
        });
        //增加积分系统，消费了多少token记录多少积分，作为后续的生态激励
        points[msg.sender] += (amount / (10 ** 18));
        return true;
    }

    /**
     *丢瓶子方法
     * @param _greetings 祝福语
     * @param amount 金额
     */
    function throwBottle(
        string memory _greetings,
        uint256 amount
    )
        external
        nftHolding
        userExist
        balanceCheck(amount)
        operationFeeCheck(throwFee, amount)
        returns (bool)
    {
        require(userExists[msg.sender], "user exists"); //判断用户存在,否则不可执行后续操作
        require(bytes(_greetings).length > 0 && bytes(_greetings).length<=80, "greetings can not empty");
        UserInfo memory userInfo = userInfos[msg.sender];
        //转账,需要对方在前端预先授权, 授权之后,将调用方的 suppportingtoken转给当前合约地址
        supportingToken.transferFrom(msg.sender, address(this), amount);
        uint256 currentBottleId = bottleIds.current();
        bottles[currentBottleId] = Bottle({
            bottleId: currentBottleId,
            userId: msg.sender,
            greetings: _greetings,
            wechat: userInfo.wechat
        });
        //消费多少就给多少积分
        points[msg.sender] += (amount / (10 ** 18));
        bottleIds.increment();
        emit ThrowBottle(msg.sender, currentBottleId, amount);
        return true;
    }

    /**
     *根据id捡瓶子事件
     * @param _bottleId 瓶子id
     * @param amount 金额
     */
    function catchDriftBottleById(
        uint256 _bottleId,
        uint256 amount
    )
        external
        nftHolding
        userExist
        balanceCheck(amount)
        operationFeeCheck(catchFee, amount)
        returns (bool)
    {
        Bottle storage bottle = bottles[_bottleId];
        if (bottle.bottleId == 0) {
            revert BottleNotExist(_bottleId);
        }

        if (bottle.userId == msg.sender) {
            revert OpenYourselfBotterError(bottle.bottleId);
        }
        //平台收一部分的手续费
        supportingToken.transferFrom(msg.sender, address(this), chargeFee);
        //剩下的给丢瓶子的用户转，鼓励用户丢瓶子
        supportingToken.transferFrom(
            msg.sender,
            bottle.userId,
            (amount - chargeFee)
        );
        points[msg.sender] = (amount / (10 ** 18));
        emit CatchBottle(
            msg.sender,
            bottle.userId,
            bottle.bottleId,
            bottle.greetings,
            bottle.wechat,
            amount
        );
        delete bottles[_bottleId]; //删除瓶子id  调用方花钱了，那么就等前端界面返回值的时候，取topic，获得wechat
        return true;
    }

    /**
     * 设置运营者参数，仅供owner调用
     * @param _registerFee 注册费
     * @param _throwFee 丢瓶子费用
     * @param _catchFee 捡瓶子费用
     * @param _swapRate 兑换比例
     * @param _chargeFee 平台抽成
     */
    function setParameter(
        uint256 _registerFee,
        uint256 _throwFee,
        uint256 _catchFee,
        uint256 _swapRate,
        uint256 _chargeFee
    ) external onlyOwner returns (bool) {
        require(_registerFee > 0, "can not be 0");
        require(_throwFee > 0, "can not be 0");
        require(_catchFee > 0, "can not be 0");
        require(_swapRate > 0, "can not be 0");
        require(_chargeFee > 0, "can not be 0");
        require(_chargeFee < _catchFee, "chargefee must less than catchFee");

        registerFee = _registerFee;
        throwFee = _throwFee;
        catchFee = _catchFee;
        swapRate = _swapRate;
        chargeFee = _chargeFee;

        emit ParameterChanged(
            msg.sender,
            registerFee,
            throwFee,
            catchFee,
            swapRate,
            chargeFee
        );
        return true;
    }

    /**
     * 查看当前瓶子的id最大值
     */
    function viewCurrentBottleId() external view returns (uint256) {
        return bottleIds.current();
    }

    /**
     * 
     * @param userId 用户地址
     * @return _userId 用户地址
     * @return _name 用户名
     * @return _gender 性别
     * @return _age 年龄
     * @return _wechat 微信
     */
    function viewUserInfoById(address userId) public view returns(address _userId,string memory _name,uint8 _gender,uint8 _age,string memory _wechat){
        UserInfo storage user = userInfos[userId];
        (_userId,_name,_gender,_age,_wechat) = (user.userId,user.name,user.gender,user.age,user.wechat);
        return (_userId,_name,_gender,_age,_wechat);        
    }

    /**
     * 参加ico方法
     */
    function joinICO() external payable returns (bool) {
        uint256 amount = msg.value * swapRate;
        require(supportingToken.balanceOf(address(this)) >= amount, "sold out");
        //参加ico也给积分奖励
        points[msg.sender] += (amount / (10 ** 18));
        supportingToken.transferFrom(address(this), msg.sender, amount);
        emit JoinICO(msg.sender, amount);
        return true;
    }

    /**
     *  回购LFT,将LFT转到当前合约中，并将eth转给发送方，按照固定的兑换比例
     * @param amount 回购的金额
     */
    function buyBack(uint256 amount) external returns (bool success) {
        require(amount > 0, "can't be zero");
        uint256 ethAmount = amount / swapRate;
        require(
            supportingToken.balanceOf(msg.sender) >= amount,
            "token not enough"
        );
        require(address(this).balance >= ethAmount, "eth not enough");
        //将用户的token转到合约中
        supportingToken.transferFrom(msg.sender, address(this), amount);
        //将合约中对应数量的eth返还给
        (success, ) = payable(msg.sender).call{value: ethAmount}("");
        emit Swap(msg.sender, amount);
        return success;
    }

    /**
     * owner取款token, 将合约中的offer token转给调用方,也就是owner
     * @param amount 提现金额
     */
    function withdrawToken(uint256 amount) external onlyOwner returns (bool) {
        //当前合约offeringToken余额必须大于等于取款金额
        require(amount > 0, "amount can not be 0 ");
        require(
            supportingToken.balanceOf(address(this)) >= amount,
            " balance not enough"
        );
        supportingToken.transferFrom(address(this), msg.sender, amount); //将合约中的offer token转给调用方,也就是owner
        return true;
    }

    /**
     * 供owner调用,将当前合约中的eth 提现出来.
     * @param amount 提现金额
     */
    function withdrawETH(
        uint256 amount
    ) external payable onlyOwner returns (bool success) {
        require(amount > 0, "amount can not be 0 ");
        require(address(this).balance >= amount, " balance not enough");
        //    (bool success,) = _to.call{value: amount}("");
        (success, ) = payable(msg.sender).call{value: amount}("");
        return success;
    }
}
