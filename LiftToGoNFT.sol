// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract LiftToGoNFT is ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    /*
    */
    uint16  public immutable MAX_SUPPLY;
    

    /*
    定义构造函数 指定token名称,token代号
    */
    constructor(uint16 maxSupply) ERC721("LiftToGoVerse", "LFT") {
        MAX_SUPPLY = maxSupply;
    }

    function mintNFT(address player, string memory tokenUri)
        public
        returns (uint256)
    {
        uint256 newItemId = _tokenIds.current(); //获得当前nft 的token id
        require(MAX_SUPPLY >= newItemId,"only 5000 offered");
        _mint(player, newItemId); //调用父类方法mint nft
        _setTokenURI(newItemId, tokenUri); //设置tokenid以及当前id对应的图片uri
        _tokenIds.increment(); //token id自增
        return newItemId;
    }
}
