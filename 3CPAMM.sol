// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "IERC20.sol";

contract CPAMM{
    IERC20 public immutable token0;
    IERC20 public immutable token1;

    uint public reserve0;//token0 amount in contract == x
    uint public reserve1;//token1 amount in contract == y

    uint public totalSupply; //lp token amount of all
    mapping(address=>uint) public balanceOf; //每个地址对应的LP余额

    constructor(address _token0,address _token1){
        token0=IERC20(_token0);
        token1=IERC20(_token1);
    }
    //  更新余额表
    function _updata(uint _reserve0,uint _reserve1) private {
        reserve0=_reserve0;
        reserve1=_reserve1;
    }

    function _sqrt(uint y) internal pure returns(uint z){
        if(y>3){
            z=y;
            uint x=y/2+1;
            while(x<z){
                z=x;
                x=(y/x+x)/2;
            }
        }else if(y!=0){
            z=1;
        }
    }

    function _mint(address _to,uint _amount) private {
        balanceOf[_to]+=_amount;
        totalSupply+=_amount;
    }

    function _burn(address _from,uint _amount) private {
        balanceOf[_from]-=_amount;
        totalSupply-=_amount;
    }

    function swap(address _tokenIn,uint _amountIn) external returns(uint amountOut){
       require(_amountIn>0,"Invalid Amount");
       require(_tokenIn==address(token0)||_tokenIn ==address(token1),"Invalid token type");

       bool isToken0=_tokenIn==address(token0);
        (IERC20 _tokenIn,IERC20 tokenOut)= isToken0?(token0,token1):(token1,token0);
        //定义顺序
        (uint reserveIn,uint reserveOut)=isToken0?(reserve0,reserve1):(reserve1,reserve0);
       //转币到合约
       _tokenIn.transferFrom(msg.sender, address(this), _amountIn);
       //计算输出的数量  注：没有考虑手续费
       amountOut=(_amountIn*reserveOut)/(_amountIn+reserveIn);
       //转币给用户 
       tokenOut.transfer(msg.sender, amountOut);
        //更新余额表
        _updata(token0.balanceOf(address(this)),token0.balanceOf(address(this)));

    }

    function _min(uint _x,uint _y) private pure returns(uint) {
        return _x>_y?_y:_x;
    }

    //用户提供的是Δx,Δy，拿到的是Share
    function addLiquidity(uint _amount0,uint _amount1) external returns (uint shares){
        require(_amount0>0&&_amount1>0,"Invaiid amount");
        //将token0、token1转入合约
        token0.transferFrom(msg.sender, address(this), _amount0);
        token1.transferFrom(msg.sender, address(this), _amount1);
        //计算并mint share给用户
        if(reserve0>0||reserve1>0){
            require(_amount0*reserve1==_amount1*reserve0,"dy/dx != y/x");           
        }
        if(totalSupply==0){
            //没有添加过流动性//添加过流动性
            shares=_sqrt(_amount0*_amount1);
        }else{
            shares=_min((_amount0*totalSupply)/reserve0,(_amount1*totalSupply)/reserve1);
        }
        require(shares>0,"share is zero");
        _mint(msg.sender, shares);
        //更新余额表
        _updata(token0.balanceOf(address(this)),token0.balanceOf(address(this)));
    }

    function removeLiquidity(uint _shares) external returns(uint _amount0,uint _amount1){
        require(_shares>0,"Invalid shares");
        //计算Δx,Δy数量
        _amount0=(reserve0*_shares)/totalSupply;
        _amount1=(reserve1*_shares)/totalSupply;
        //销毁用户的share
        _burn(msg.sender, _shares);
        //将两个币转回给用户
        token0.transfer(msg.sender, _amount0);
        token1.transfer(msg.sender, _amount1);
        //更新余额表
        _updata(token0.balanceOf(address(this)),token0.balanceOf(address(this)));
    }

}