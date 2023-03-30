// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
author: rongqiang.li

我的疑问
1: 我是否需要一个初始化 initialize 函数的功能,作为项目方把offertoken转到当前合约,还是直接用钱包直接将当前token转到 当前合约地址当中
2: 关于是使用 transferFrom 还是transfer,怎么觉得写的怪怪的. TODO 转账操作用那个会比较好. 
3: //TODO  amount * swapRate  怎么处理不越界,使得这个金额有意义?
4: //TODO 其实已经授权,是用 require比较好,还是什么都不做,返回true,需要给用户警告吗
5: //TODO offeringToken.balanceOf(address(this)) = balance 要多次使用的这个值,并且这个值是不会修改的,是用一个变量存还是多次取会比较好
6: //我要怎么去测试我这个ico合约是不是ok ,怎么添加测试token,怎么发token
*/
contract MyICOContract {
    /*
    定义一个公共状态变量,记录合约的所有者.
    */
    address public immutable owner;
    /*
    定义一个公共状态变量,记录ico是否结束.
    */
    bool public ended;

     // The LP token address 参与的token地址 
    ERC20 public lpToken;

    // The offering token,项目方发售的合约token地址
    ERC20 public offeringToken;

    uint256 public immutable swapRate;

    /*用户参与ico信息*/
    mapping(address => uint256) public userOfferingInfo;

    /*
    定义一个事件,记录参与ico的地址和对应的lptoken金额,以及获得的项目token amount
    */
    event Deposit(address indexed spender,uint256 lpTokenAmount,uint256 offeringTokenAmount);

    /*
    定义一个事件,记录owner从合约中提取 lptoken的数量
    */
    event Withdraw(address indexed recipient,uint256 amount);
    /**
    定义一个事件结束ICO
    */
    event Ended(address indexed owner);

    /*
    */
    modifier onlyOwner(){
        require(msg.sender == owner,"Operations: only owner");
        _;
    }


    /*
    ICO合约的构造函数,传入三个参数与, 参与资金token的地址,项目方发售token的地址,以及兑换比例
    */
    constructor(address _lptoken,address _offeringToken,uint8 _swapRate) {
        owner = msg.sender;
        lpToken = ERC20(_lptoken);
        offeringToken = ERC20(_offeringToken);
        swapRate = _swapRate;
    }

    /**
    处理授权将lptoken的转账权限授予给当前合约地址
    */
    function approve(uint256 allowAmount) external returns(bool) {
        //将msg.sender地址上的lptoken的转账权限赋予给当前合约
        uint256 allowedAmount = lpToken.allowance(msg.sender,address(this));
        //allowance
        if(allowedAmount >= allowAmount){
            //TODO 其实已经授权,是用 require比较好,还是什么都不做,返回true
            return true;
        }
        lpToken.approve(address(this),allowAmount);
        return true;
    }

    /*
    处理结束ICO的请求,只有owner可以操作
    */
    function closeICO() external onlyOwner returns(bool) {
        require(!ended,"already ended");
        ended = true;
        emit Ended(msg.sender);
        return ended;
    }

    /*
    处理ICO的请求, 用户将指定的token 发送到当前合约中,我们合约同步立即将项目方发售的token发给msg.sender 
    */
    function deposit(uint256 amount) external returns(bool){
        require(!ended,"ico ended");
        require(amount>0,"must more than 0 token");//参与的金额必须为正数
        require(lpToken.balanceOf(msg.sender) >= amount, "your balance not Enough");//msg.sender的lptoken余额必须大于等于参与金额.
        uint256 offeringAmount = amount * swapRate; //TODO 怎么处理不越界,使得这个金额有意义?
        
        require(offeringToken.balanceOf(address(this)) >= offeringAmount,"offering token not Enough");//合约的offertoken必须要大于等于当前金额乘以兑换笔录的乘积


        //将当前地址的 lptoken 转账到当前合约中
        lpToken.transferFrom(address(msg.sender), address(this), amount);

        // TODO 转账操作用那个会比较好. 

        //把合约中的offeringtoken转账给msg.sender
        offeringToken.transferFrom(address(this),address(msg.sender), offeringAmount);

        //将用户参与的金额放入到 userOfferingInfo mapping中
        userOfferingInfo[msg.sender] += userOfferingInfo[msg.sender];

        // todo offeringToken.balanceOf(address(this)) = balance 要多次使用的这个值,并且这个值是不会修改的,是用一个变量存还是多次取会比较好

        if(offeringToken.balanceOf(address(this)) ==0){
            ended = true;
        }

        emit Deposit(msg.sender,amount,offeringAmount);
        return true;
    }


    /*ICO 发起人提现*/
    function withdraw(uint256 amount) external onlyOwner returns(bool){
        require(ended,"ico not ended,cannot withdraw");
        //提现金额必须小于等于当前合约地址中的余额.
        require(lpToken.balanceOf(address(this))>amount);
        // 将当前合约中的lptoken数量转账到owner地址

        lpToken.transferFrom(address(this),msg.sender,amount);
        emit Withdraw(msg.sender,amount);
        return true;
    }

    /**
    提供用户一个查询某个地址参与的ico信息
    */
    function viewUserOfferingInfo(address userAddress) external view returns(uint256){
        return userOfferingInfo[userAddress];
    }

    
}
