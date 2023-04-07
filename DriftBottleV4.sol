// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @author lrqstudy
/// @dev 我的练手项目,区块链漂流瓶 driftbottle, 跟我们现实世界中玩的一样

/// @dev https://github.com/lrqstudy/learn-smart-contract/blob/main/DriftBottleV3.sol

/*
v4版本

由于写合约返回参数是无法返回的,必须要把参数放到eventlog中去,因此修改CatchBottle 将需要返回的值通过eventlog形式传递出去.
增加greetings和wechat的字段,前端通过receiptTransaction对象去获取到数据. 用indexed 去获取,
因此必须要返回捡瓶子的人和瓶子id以及微信号和打招呼用语

*/
contract DriftBottleV4 {
    //当前用户数据mapping定义为私有
    mapping(address => UserInfo) private userInfos;

    //增加一个标记,用于判断用户是否已经注册
    mapping(address => bool) private userExists;

    //支持的token
    ERC20 public supportingToken;

    //合约创建者
    address public immutable owner;

    //漂流瓶自增id 这个应该改为public
    uint64 public bottleId = 1;

    //漂流瓶mapping
    mapping(uint64 => Bottle) private driftBottles;

    //漂流瓶状态mapping
    mapping(uint64 => bool) bottleFlag;

    /// 注册花费
    uint256 public registerFee = 200 * (10**18);

    /// 捡瓶子花费
    uint256 public catchFee = 50 * (10**18);

    // 丢瓶子花费
    uint256 public throwFee = 10 * (10**18);

    //eth 换 token的比例,如1000 则代表 1Eth = 1000 token
    uint256 public swapRate = 1000;

    /*
    用户结构
    */
    struct UserInfo {
        //用户地址
        address userId;
        //用户名,不唯一
        string name;
        //用户性别true代表男,有jb,false代表女 无jb
        bool gender;
        //年龄
        uint8 age;
        //微信id(8-28位)
        string wechat;
    }

    /*
    漂流瓶结构
    */
    struct Bottle {
        //bottle id
        uint64 bottleId;
        //用户地址,作为id
        address userId;
        //打招呼用语
        string greetings;
        //微信id(8-28位)
        string wechat;
        //状态true为已经打开,false为还未打开
        bool opened;
    }

    /*构造函数,指定支持的token合约地址 */
    constructor(address _supportingToken) {
        owner = msg.sender;
        supportingToken = ERC20(_supportingToken);
    }

    /*
    定义一个修饰符,用于校验调用方只允许是owner
    */
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    /*
    定义一个修饰符，用于校验各个操作需要的费用
    */
    modifier operationFeeCheck(uint256 operationFee, uint256 amount) {
        require(amount > operationFee, " less than operationFee ");
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
    注册事件, 记录用户地址和花费金额
    */
    event Register(address indexed userId, uint256 amount);

    /*
    丢漂流瓶事件,记录用户地址和花费金额
    */
    event ThrowBottle(address indexed userId, uint64 bottleId, uint256 amount);

    /*
    捡漂流瓶事件:记录漂流瓶id,用户地址和花费金额.
    */
    event CatchBottle(address indexed userId, uint64 bottleId,string greetings,string wechat, uint256 amount);

    /*
    设置参数事件通知
    */
    event ParameterChanged(
        address indexed owner,
        uint256 registerFee,
        uint256 catchFee,
        uint256 throwFee,
        uint256 swapRate
    );

    /*
    注册方法，用于新用户注册, 注册要花20个token
    */
    function register(
        string memory name,
        bool gender,
        uint8 age,
        string memory wechat,
        uint256 amount
    )
        public
        operationFeeCheck(registerFee, amount)
        balanceCheck(amount)
        returns (bool)
    {
        require(!userExists[msg.sender], "user exists");//判断用户不存在继续执行后续逻辑
        require(age > 0, "age must positive");
        require(bytes(name).length > 0, "name cannot empty"); //字符串如何判断不为空
        require(
            bytes(wechat).length >= 8 && bytes(wechat).length <= 28,
            "wechat length must be 8 to 28"
        ); //微信号只能是8-28位

        //转账,需要对方在前端预先授权, 授权之后,将调用方的 suppportingtoken转给当前合约地址
        supportingToken.transferFrom(msg.sender, address(this), amount);
        userInfos[msg.sender] = UserInfo({
            userId: msg.sender,
            name: name,
            gender: gender,
            age: age,
            wechat: wechat
        });
        emit Register(msg.sender, amount);
        return true;
    }

    /*
    丢漂流瓶方法，处理丢漂流瓶，每个人最多10个漂流瓶，丢一次 20个token, 参数可以配置
    */
    function throwBottle(string memory _greetings, uint256 amount)
        external
        operationFeeCheck(throwFee, amount)
        balanceCheck(amount)
        returns (bool)
    {
        require(userExists[msg.sender], "user exists");//判断用户存在,否则不可执行后续操作
        require(bytes(_greetings).length > 0, "greetings can not empty");
        UserInfo memory userInfo = userInfos[msg.sender];
        require(
            supportingToken.balanceOf(msg.sender) >= amount,
            "balance not enough"
        );
        //转账,需要对方在前端预先授权, 授权之后,将调用方的 suppportingtoken转给当前合约地址
        supportingToken.transferFrom(msg.sender, address(this), amount);

        driftBottles[bottleId] = Bottle({
            bottleId: bottleId,
            userId: msg.sender,
            greetings: _greetings,
            wechat: userInfo.wechat,
            opened: false
        });
        bottleFlag[bottleId] = false;
        emit ThrowBottle(msg.sender, bottleId, amount);
        bottleId++; //bottle id自增
        return true;
    }

    /*
    根据id捡起漂流瓶 花20个 token
    */
    function catchDriftBottleById(uint64 _bottleId, uint256 amount)
        external
        operationFeeCheck(catchFee, amount)
        balanceCheck(amount)
        returns (string memory _greetings, string memory _wechat)
    {

        require(userExists[msg.sender], "user exists");//判断用户存在,否则不可执行后续操作
        //如果漂流瓶已经打开,则交易回滚
        require(!bottleFlag[_bottleId], "bottle opened");
        Bottle storage bottle = driftBottles[_bottleId];
        require(
            bottle.bottleId != 0 && !bottle.opened,
            "Operation: bottle not exist"
        );
        (_greetings, _wechat) = (bottle.greetings, bottle.wechat);
        //转账,需要对方在前端预先授权, 授权之后,将调用方的 suppportingtoken转给当前合约地址
        supportingToken.transferFrom(msg.sender, address(this), amount);
        bottle.opened = true; //将当前漂流瓶状态设置为已打开
        delete driftBottles[_bottleId]; //已经打开的漂流瓶从mapping中删除
        bottleFlag[_bottleId] = true; //将漂流瓶状态设置为已打开
        emit CatchBottle(msg.sender, _bottleId,_greetings,_wechat, amount);
        return (_greetings, _wechat);
    }

    /*
    根据bottleId查询漂流瓶id 和状态
    */
    function viewBottleByBottleId(uint64 _bottleId)
        public
        view
        returns (uint64, bool)
    {
        if (bottleFlag[_bottleId]) {
            //如果bottleFlag中记录的bottleid状态已经打开,则直接返回当前bottleId 和true,说明当前bottleid已经打开,不需要再查对应的bottle结构对象
            return (_bottleId, true);
        }
        return (
            driftBottles[_bottleId].bottleId,
            driftBottles[_bottleId].opened
        );
    }

    /*
    只能是owner操作,设置dapp运营的参数
    */
    function setParameter(
        uint256 _registerFee,
        uint256 _throwFee,
        uint256 _catchFee,
        uint256 _swapRate
    ) external onlyOwner returns (bool) {
        require(_registerFee > 0, "can not be 0");
        require(_throwFee > 0, "can not be 0");
        require(_catchFee > 0, "can not be 0");
        require(_swapRate > 0, "can not be 0");

        registerFee = _registerFee;
        throwFee = _throwFee;
        catchFee = _catchFee;
        swapRate = _swapRate;

        emit ParameterChanged(
            msg.sender,
            registerFee,
            throwFee,
            catchFee,
            swapRate
        );
        return true;
    }

    /*
    根据地址查看用户信息
    */
    function viewUserInfo(address userId)
        public
        view
        returns (
            string memory _name,
            bool _gender,
            uint8 _age
        )
    {
        (_name, _gender, _age) = (
            userInfos[userId].name,
            userInfos[userId].gender,
            userInfos[userId].age
        );
        return (_name, _gender, _age);
    }

    /*
    接收eth 并且在offertoken余额充足的情况下, 把offeringtoken 转给调用方.  这里就直接相当于是ICO了
    */
    receive() external payable {
        //接收到eth,就给对方转 swapRate倍的 supportToken
        uint256 getTokenAmount = msg.value * swapRate;
        require(supportingToken.balanceOf(address(this)) >= getTokenAmount); //校验余额充足
        // 如果余额充足就给对方转接收到eth,就给对方转 100倍的 supportToken
        supportingToken.transfer(msg.sender, getTokenAmount); //将合约中的offeringtoken转给调用方,也就是打eth进来的人
    }

    /*
        owner取款token, 将合约中的offer token转给调用方,也就是owner
    */
    function withdrawToken(uint256 amount) external onlyOwner returns (bool) {
        //当前合约offeringToken余额必须大于等于取款金额
        require(amount > 0, "amount can not be 0 ");
        require(
            supportingToken.balanceOf(address(this)) >= amount,
            " balance not enough"
        );
        supportingToken.transfer(msg.sender, amount); //将合约中的offer token转给调用方,也就是owner
        return true;
    }

    /*
    供owner调用,将当前合约中的eth 提现出来.
    */
    function withdrawETH(uint256 amount)
        external
        payable
        onlyOwner
        returns (bool)
    {
        require(amount > 0, "amount can not be 0 ");
        require(address(this).balance >= amount, " balance not enough");
        //address(this).transfer(msg.sender,amount);
        payable(msg.sender).transfer(amount); //将合约中的eth转给调用方.
        return true;
    }
}
