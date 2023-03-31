// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @author lrqstudy
/// @dev 我的练手项目,区块链漂流瓶 driftbottle, 跟我们现实世界中玩的一样.但是无法避免自己取到自己的漂流瓶,漂流瓶放的是自己的微信id

/*
我的问题:
1. 目前微信号存储在链上,如果有区块链浏览器其实是可以看出来的,有什么好用的加密方式么,链上加密, 捞瓶子的人付费后可以直接查看,目前无法做到,项目直接做不了了
2. 漂流瓶暂时无法便利,没办法做到自己不拿到自己的漂流瓶. 暂时没想到好的数据结构做到
3. receive函数,用户给我打eth,但是我的offeringtoken不够了, 其实应该要给对方推敲, 怎么给对方退钱? TODO 直接把value转回去吗还是怎么拒收? 
4. 目前的合约不支持升级,我预留了withdraw函数,好像应该加上withdraw eth 函数.
*/
contract DriftBottle {

    //当前用户数据mapping定义为私有 
    mapping(address =>UserInfo) private userInfos;

    //支持的token
    ERC20 public supportingToken;

    //合约创建者
    address public immutable owner;

    //漂流瓶数组
    Bottle[] private driftBottles;
    /// 注册花费
    uint256 public registerFee = 200 * (10**18);

    /// 捡瓶子花费
    uint256 public catchFee = 50* (10**18);

    // 丢瓶子花费
    uint256 public throwFee = 10* (10**18);

    //eth 换 token的比例
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
    constructor(address _supportingToken)  {
        owner = msg.sender;
        supportingToken = ERC20(_supportingToken);
    }

    /*
    定义一个修饰符,用于校验调用方只允许是owner
    */
    modifier onlyOwner(){
        require(msg.sender == owner);
        _;
    }

    /*
    定义一个修饰符，用于校验各个操作需要的费用
    */
    modifier operationFeeCheck(uint256 operationFee,uint256 amount){
        require(amount> operationFee," less than operationFee ");
        _;
    }

    /*
    定义一个校验修饰符,用于校验操作对象当前token的余额是否足够
    */
    modifier balanceCheck(uint256 amount){
        require(supportingToken.balanceOf(msg.sender) >= amount,"balance not enough");
        _;
    }

    /*
    注册事件, 记录用户地址和花费金额
    */
    event Register(address indexed userId,uint256 amount);

    /*
    丢漂流瓶事件,记录用户地址和花费金额
    */
    event ThrowBottle(address indexed userId,uint256 amount);

    /*
    捡漂流瓶事件:记录用户地址和花费金额.
    */
    event CatchBottle(address indexed userId,uint256 amount);

    /*
    设置参数事件通知
    */
    event ParameterChanged(address indexed owner,uint256 registerFee,uint256 catchFee,uint256 throwFee,uint256 swapRate);

    /*
    注册方法，用于新用户注册, 注册要花20个token
    */
    function register(string memory name,bool gender,uint8 age,string memory wechat,uint256 amount) public operationFeeCheck(registerFee,amount) balanceCheck(amount) returns(bool){
        UserInfo storage user = userInfos[msg.sender];
        require(user.age ==0, "user exists");//如果user.age 不等于0 那么说明用户之前信息存在的.
        require(age > 0,"age must positive");
        require(bytes(name).length >0,"name cannot empty"); //字符串如何判断不为空
        require(bytes(wechat).length >=8 && bytes(wechat).length<= 28,"wechat length must be 8 to 28"); //微信号只能是8-28位

        //转账,需要对方在前端预先授权, 授权之后,将调用方的 suppportingtoken转给当前合约地址
        supportingToken.transferFrom(msg.sender,address(this),amount);

        userInfos[msg.sender] = UserInfo({
            userId:msg.sender,
            name:name,
            gender:gender,
            age:age,
            wechat:wechat
        });

        emit Register(msg.sender,amount);
        return true;
    }


    /*
    丢漂流瓶方法，处理丢漂流瓶，每个人最多10个漂流瓶，丢一次 20个token, 参数可以配置
    */
    function throwBottle(string  memory _greetings,uint256 amount) external operationFeeCheck(throwFee,amount) balanceCheck(amount)  returns(bool){
        require(bytes(_greetings).length>0,"greetings can not empty");
        UserInfo memory userInfo = userInfos[msg.sender];
        require(userInfo.age >0,"you should register first");
        require(supportingToken.balanceOf(msg.sender) >=amount,"balance not enough");

        //转账,需要对方在前端预先授权, 授权之后,将调用方的 suppportingtoken转给当前合约地址
        supportingToken.transferFrom(msg.sender,address(this),amount);

        driftBottles.push(Bottle({
            userId: msg.sender,
            greetings:_greetings,
            wechat:userInfo.wechat,
            opened:false
        }));

        emit ThrowBottle(msg.sender,amount);
        
        return true;
    }

    /*
    捡起漂流瓶 花20个 token
    */
    function catchDriftBottle(uint256 amount) external operationFeeCheck(catchFee,amount) balanceCheck(amount)  returns(string memory _greetings,string memory _wechat){
        //不能捡起自己的怎么判断，加不了，就随意吧. 
        require(driftBottles.length >0,"no drift bottle");
        (_greetings,_wechat) = (driftBottles[0].greetings,driftBottles[0].wechat);
        supportingToken.transfer(msg.sender,amount);
        
        //转账,需要对方在前端预先授权, 授权之后,将调用方的 suppportingtoken转给当前合约地址
        supportingToken.transferFrom(msg.sender,address(this),amount);

        driftBottles[0].opened = true;//捡起来直接将当前漂流瓶归0
        delete driftBottles[0];//上面那个操作true也没啥用了,已经删除了
        emit CatchBottle(msg.sender,amount);
        return (_greetings,_wechat);
    }

    /*
    只能是owner操作,设置dapp运营的参数
    */
    function setParameter(uint256 _registerFee,uint256 _throwFee,uint256 _catchFee,uint256 _swapRate) external onlyOwner returns(bool){
        require(_registerFee>0,"can not be 0");
        require(_throwFee>0,"can not be 0");
        require(_catchFee>0,"can not be 0");
        require(_swapRate>0,"can not be 0");

        registerFee = _registerFee;
        throwFee = _throwFee;
        catchFee = _catchFee;
        swapRate = _swapRate;

        emit ParameterChanged(msg.sender,registerFee,throwFee,catchFee,swapRate);
        return true;
    }

    /*
    根据地址查看用户信息
    */
    function viewUserInfo(address userId) public view returns(string memory _name,bool _gender,uint8 _age){
        (_name,_gender,_age) = (userInfos[userId].name,userInfos[userId].gender,userInfos[userId].age);
        return  (_name,_gender,_age);
    }

    /*
    接收eth 并且在offertoken余额充足的情况下, 把offeringtoken 转给调用方.  这里就直接相当于是ICO了
    */
    receive() external payable{
         //接收到eth,就给对方转 swapRate倍的 supportToken
         if(msg.value ==0){
             return;
         }
        uint256 getTokenAmount = msg.value * swapRate;
        // 如果余额充足就给对方转接收到eth,就给对方转 100倍的 supportToken, 如果offeringtoken 余额不够,就谢谢大佬
        if(supportingToken.balanceOf(address(this))> getTokenAmount){
            supportingToken.transfer(msg.sender,getTokenAmount);//将合约中的offeringtoken转给调用方,也就是打eth进来的人
        }
    }

    /*
        owner取款token, 将合约中的offer token转给调用方,也就是owner
    */
    function withdraw(uint256 amount) external onlyOwner returns(bool){
        //当前合约offeringToken余额必须大于等于取款金额
        require(amount>0,"amount can not be 0 ");
        require(supportingToken.balanceOf(address(this))>= amount," balance not enough");
        supportingToken.transfer(msg.sender,amount);//将合约中的offer token转给调用方,也就是owner
        return true;
    }

    /*
    供owner调用,将当前合约中的eth 提现出来.
    */
    function withdrawETH(uint256 amount) external payable onlyOwner returns(bool){
        require(amount>0,"amount can not be 0 ");
        require(address(this).balance >= amount," balance not enough");
        //address(this).transfer(msg.sender,amount);
        payable(msg.sender).transfer(amount);//将合约中的eth转给调用方.
        return true;
    }

}
