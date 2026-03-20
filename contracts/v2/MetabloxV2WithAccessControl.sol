// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/common/ERC2981Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
// import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "../storage/PropertyTier.sol";
import "../storage/PropertyLevel.sol";

/// @title MetaBloxV2 main contract
/// @author Kevin, Chung
/// @notice MetaBloxV2 main contract.
/// @dev This contract is for testing only. Should create another one to change token and pool addresses below
contract MetabloxV2WithAccessControl is
    ERC721EnumerableUpgradeable,
    ERC721URIStorageUpgradeable,
    ERC2981Upgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    /* libs */
    using SafeERC20Upgradeable for ERC20Upgradeable;
    using SafeMath for uint256;
    using StringsUpgradeable for uint256;

    /* chainlink registration table */
    mapping (string => address) public registeredToken;
    mapping (string => address) public registeredPriceFeed;
    mapping (uint => bool) public isLandmark;
    
    string public contractUri;

    uint256 constant BASE_TOLERANCE = 1e4; // tolerance decimals: 4
    uint256 constant TOLERANCE_PADDING = 1e22; // 100 matic

    /* public params */
    address public beneficiary;
    address public propertyTierContractAddress;
    address public propertyLevelContractAddress;

    bool public allBloxesSold;
    uint256 public phase;
    uint256 public bloxSupply;
    uint256 public bloxSupplyWithLandmark;
    uint256 public maxPublicMintAmount;
    uint256 public maxReserveMintAmount;
    uint public gracePeriodAmount;
    uint public gracePeriodRemaining;
    uint public gracePeriodCurrent;
    mapping (uint => uint) public gracePeriodBlockNumber;

    /* private params */
    mapping (uint=>bool) public cappedBlox;

    // events
    event EnteringGracePeriod(address indexed _addr, uint _gracePeriod, uint _timestamp);
    event ReleasingGracePeriod(address indexed _addr, uint _gracePeriod, uint _timestamp);

    /// @custom:oz-upgrades-unsafe-allow constructor
    // constructor() initializer {}

    string public baseURI;
    string public customURI;

    address private capper;
    address private minter;

    function initialize(
        string memory _name,
        string memory _symbol,
        address _beneficiary,
        address _propertyTierContractAddress,
        address _propertyLevelContractAddress,
        address[] memory _tokenRelatedAddresses
    ) public initializer {
        __ERC721_init(_name, _symbol);
        __ERC721Enumerable_init();
        __ERC2981_init();
        __ERC721URIStorage_init();
        __Ownable_init();
        __UUPSUpgradeable_init();

        __Blox_init(_beneficiary, _propertyTierContractAddress, _propertyLevelContractAddress, _tokenRelatedAddresses);
    }

    function __Blox_init(
        address _beneficiary,
        address _propertyTierContractAddress,
        address _propertyLevelContractAddress,
        address[] memory _tokenRelatedAddresses
    ) internal {
        phase = 1;
        
        allBloxesSold = false;
        gracePeriodRemaining = 0;

        maxReserveMintAmount = 20;
        maxPublicMintAmount = 5;

        beneficiary = _beneficiary;
        propertyTierContractAddress = _propertyTierContractAddress;
        propertyLevelContractAddress = _propertyLevelContractAddress;
        
        registeredToken["USDT"] = address(_tokenRelatedAddresses[0]);
        registeredToken["WETH"] = address(_tokenRelatedAddresses[1]);
        registeredToken["WMATIC"] = address(_tokenRelatedAddresses[2]);
        registeredPriceFeed["WETH"] = address(_tokenRelatedAddresses[3]);
        registeredPriceFeed["MATIC"] = address(_tokenRelatedAddresses[4]);
    }

    modifier onlyCapper() {
        require(capper == _msgSender(), "caller is not the capper");
        _;
    }

    modifier onlyMinter() {
        require(minter == _msgSender(), "caller is not the minter");
        _;
    }

    function capBloxBeforePayment(uint _bloxId) public onlyCapper {
        require(!_exists(_bloxId), "the blox has been minted");
        cappedBlox[_bloxId] = true;
    }

    function setTotalBloxSupply(uint _bloxSupply) external onlyOwner {
        bloxSupply = _bloxSupply;
    }

    function setTotalBloxSupplyWithLandmark(uint256 _bloxSupplyWithLandmark) external onlyOwner {
        bloxSupplyWithLandmark = _bloxSupplyWithLandmark;
    }

    function setCappedBloxes(uint[] memory _bloxIds, bool _flag) public onlyCapper {
        for (uint i=0; i<_bloxIds.length; i++) {
            cappedBlox[_bloxIds[i]] = _flag;
        }
    }

    function setMaxPublicMintAmount(uint _maxPublicMintAmount) external onlyOwner {
        maxPublicMintAmount = _maxPublicMintAmount;
    }

    function setMaxReserveAmount(uint _maxReserveMintAmount) external onlyOwner {
        maxReserveMintAmount = _maxReserveMintAmount;
    }

    function initBloxProperty(uint _bloxId) private {
        uint256[] memory _attrIds = new uint256[](4);
        _attrIds[0] = 1;
        _attrIds[1] = 2;
        _attrIds[2] = 3;
        _attrIds[3] = 4;

        uint256[] memory _attrAmounts = new uint256[](4);
        _attrAmounts[0] = 1;
        _attrAmounts[1] = 0;
        _attrAmounts[2] = 1;
        _attrAmounts[3] = 300;

        bytes[] memory _texts = new bytes[](4);

        PropertyLevel(propertyLevelContractAddress).batchAttach(_bloxId, _attrIds, _attrAmounts, _texts);
    }

    // reservation mint
    function mintReservedBlox(
        address _user,
        uint256 _bloxId
    ) public onlyMinter whenNotPaused {
        require(!allBloxesSold, "Bloxes are all sold");
        require(_bloxId <= bloxSupplyWithLandmark && _bloxId >= 1, "invalid Blox number");
        // to get custom token uri for nackword compatibility
        string memory _customURI = string(abi.encodePacked(customURI, _bloxId.toString()));

        _safeMint(_user, _bloxId);
        _setTokenURI(_bloxId, _customURI);
        initBloxProperty(_bloxId);
        // check if the blox are all sold out
        if (totalSupply() == bloxSupplyWithLandmark) {
            allBloxesSold = true;
        }
        gracePeriodCheck(_user);
    }

    // reservation batch mint
    function batchMintReservedBloxes(
        address _user,
        uint256[] memory _bloxIds
    ) public onlyMinter whenNotPaused {
        // check blox length availability
        require(_bloxIds.length <= maxReserveMintAmount && _bloxIds.length > 0, "exceed maximum mint amount");
        // check if the mint amount exceeds max blox supply
        uint _supply = totalSupply();
        require(_supply + _bloxIds.length <= bloxSupply, "exceed maximum blox supply");
        // mint execution
        for (uint i=0; i<_bloxIds.length; i++) {
            mintReservedBlox(_user, _bloxIds[i]);
        }
    }

    // public mint
    function mintBlox(
        uint256 _bloxId,
        uint8 _propertyTier,
        address _buyWith,
        uint256 _erc20TokenAmount,
        uint256 _tolerance
    ) private {
        // check if bloxes are all sold out
        require(!allBloxesSold, "Bloxes are all sold");
        // check if the blox id is available in between of 1 to total supply
        require(_bloxId <= bloxSupplyWithLandmark && _bloxId >= 1, "invalid Blox number");
        // check if the blox is capped by third party payment
        require(!cappedBlox[_bloxId], "the Blox is capped");
        // check if it's not a landmark
        require(!isLandmark[_bloxId], "the Blox is a Landmark");
        // get msg sender
        address _user = _msgSender();
        // to get custom token uri for nackword compatibility
        string memory _customURI = string(abi.encodePacked(customURI, _bloxId.toString()));
        // mint and set blox properties
        _safeMint(_user, _bloxId);
        _setTokenURI(_bloxId, _customURI);
        initBloxProperty(_bloxId);
        // check if the blox are all sold out
        if (totalSupply() == bloxSupplyWithLandmark) {
            allBloxesSold = true;
        }

        if (_buyWith == registeredToken["USDT"]) {
            ERC20Upgradeable USDT = ERC20Upgradeable(registeredToken["USDT"]);
            USDT.safeTransferFrom(_user, beneficiary, getBasePriceFromPropertyTier(_propertyTier) * 10 ** USDT.decimals());
        } else if (_buyWith == registeredToken["WETH"]) {
            ERC20Upgradeable WETH = ERC20Upgradeable(registeredToken["WETH"]);
            require (
                isAbleToMintWith(registeredPriceFeed["WETH"], _erc20TokenAmount, _tolerance * 10 ** ( 18 - WETH.decimals() ), _propertyTier),
                "unable to mint with WETH"
            );
            WETH.safeTransferFrom(_user, beneficiary, _erc20TokenAmount);
        } else if (_buyWith == registeredToken["WMATIC"]) {
            require (
                isAbleToMintWith(registeredPriceFeed["MATIC"], _erc20TokenAmount, _tolerance, _propertyTier),
                "unable to mint with MATIC"
            );
        } else {
            revert("unsupported token to mint Bloxes");
        }

        gracePeriodCheck(_user);
    }

    // reservation batch mint
    function batchMintBloxes(
        uint256[] memory _bloxIds,
        uint8[] memory _propertyTiers,
        address _buyWith,
        uint256[] memory _erc20TokenAmounts,
        uint256 _tolerance
    ) external nonReentrant whenNotPaused payable {
        // check blox length availability
        require(
            _bloxIds.length == _propertyTiers.length &&
            _propertyTiers.length == _erc20TokenAmounts.length,
            "unmatched length of array"
        );
        require(_bloxIds.length <= maxPublicMintAmount && _bloxIds.length > 0, "exceed maximum mint amount");
        // check if the mint amount exceeds max blox supply
        uint _supply = totalSupply();
        require(_supply + _bloxIds.length <= bloxSupplyWithLandmark, "exceed maximum blox supply");
        // matic special examination
        if (_buyWith == registeredToken["WMATIC"]) {
            uint _totalMaticAmount = 0;
            for (uint i=0; i<_erc20TokenAmounts.length; i++) {
                _totalMaticAmount += _erc20TokenAmounts[i];
            }
            require(msg.value >= _totalMaticAmount, "insufficient matic amount to mint bloxes");
        }
        // mint execution
        if (_bloxIds.length == 1) {
            mintBlox(_bloxIds[0], _propertyTiers[0], _buyWith, _erc20TokenAmounts[0], _tolerance);
        } else {
            for (uint i=0; i<_bloxIds.length; i++) {
                mintBlox(_bloxIds[i], _propertyTiers[i], _buyWith, _erc20TokenAmounts[i], _tolerance);
            }
        }
    }

    /**
     * @dev Check if the amount user sends is in range of tolerance so that user can mint a new blox 
     *
     * Logic:
     *
     * - get price of ERC20 token in USDT from Chainlink and save with new amount in USDT
     * - get price range from tolerance
     * - check if the new USDT amount is between the price range
     * - transfer ERC20 token from user's account to Blox's account
     * - mint Blox to user
     */
    function isAbleToMintWith(address priceFeedAddress, uint256 tokenAmount, uint256 tolerance, uint8 propertyTier) private view returns (bool) {
        // chainlink: 18 + 8 = 0 + 4 + 22
        uint256 bloxPriceInUsdt = getBasePriceFromPropertyTier(propertyTier);
        uint256 usdtPrice = getUsdtPrice(priceFeedAddress);
        if (
            (tokenAmount * usdtPrice) > 
            bloxPriceInUsdt * (BASE_TOLERANCE + tolerance) * TOLERANCE_PADDING
        ) revert("exceed tolerance range");
        if (
            (tokenAmount * usdtPrice) < 
            bloxPriceInUsdt * (BASE_TOLERANCE - tolerance) * TOLERANCE_PADDING
        ) revert("under tolerance range");

        return true;
    }

    function gracePeriodCheck(address _user) private {
        // if the reserved supply hit a specific ratio
        // grace period activates
        if (gracePeriodAmount >= 10) {
            return;
        }
        if (totalSupply() % getBloxSupplyDivBy10() == 0) {
            phase = phase.add(1);
            gracePeriodAmount = gracePeriodAmount.add(1);
            gracePeriodBlockNumber[gracePeriodAmount] = block.number;
            if (gracePeriodRemaining == 0) {
                gracePeriodCurrent = gracePeriodCurrent.add(1);
            }
            gracePeriodRemaining = gracePeriodRemaining.add(1);
            emit EnteringGracePeriod(_user, gracePeriodAmount, block.number);
        }
    }

    function getUsdtPrice(address poolAddress) internal view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(poolAddress);
        (
            uint80 roundID, 
            int256 price,
            uint startedAt,
            uint timeStamp,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        return uint256(price);
    }

    function getBasePriceFromPropertyTier(uint8 propertyTier) public view returns (uint256) {
        bool _canSub;
        uint _phase;
        uint _propertyTier;
        (_canSub, _phase) = phase.trySub(gracePeriodRemaining);
        (_canSub, _propertyTier) = uint(propertyTier).trySub(1);

        require(_canSub, "phase or property tier overflow when getting base price");

        return
            PropertyTier(propertyTierContractAddress).getBloxBasePrice(
                _phase,
                _propertyTier
            );
    }

    function getBloxSupplyDivBy10() internal view returns (uint256) {
        (bool _canDiv, uint _divided) = bloxSupply.tryDiv(10);
        require(_canDiv, "when getting divided supply");
        return _divided;
    }

    function addNewPriceFeed(string memory tokenName, address priceFeedAddress) external onlyOwner {
        require(registeredPriceFeed[tokenName] == address(0), "existing price feed");
        registeredPriceFeed[tokenName] = priceFeedAddress;
    }

    function updatePriceFeed(string memory tokenName, address priceFeedAddress) external onlyOwner {
        require(registeredPriceFeed[tokenName] != address(0), "non-existing price feed");
        registeredPriceFeed[tokenName] = priceFeedAddress;
    }

    function isApprovedForAll(
        address _owner,
        address _operator
    ) public override view returns (bool isOperator) {
        // if OpenSea's ERC721 Proxy Address is detected, auto-return true
        if (_operator == address(0x58807baD0B376efc12F5AD86aAc70E78ed67deaE)) {
            return true;
        }
        
        // otherwise, use the default ERC721.isApprovedForAll()
        return super.isApprovedForAll(_owner, _operator);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable, ERC2981Upgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /* periodcally call it every 24 hours */
    function releaseGracePeriod() external onlyOwner {
        uint _now = block.number;
        // require (
        //     gracePeriodBlockNumber[gracePeriodCurrent] != 0 && 
        //     _now - gracePeriodBlockNumber[gracePeriodCurrent] >= 24 hours,
        //     "can not release grace period within 24 hours"
        // );
        bool _canSub = false;
        (_canSub, gracePeriodRemaining) = gracePeriodRemaining.trySub(1);
        require(_canSub, "gracePeriodRemaining overflow");

        if (gracePeriodBlockNumber[gracePeriodCurrent.add(1)] != 0) {
            gracePeriodCurrent = gracePeriodCurrent.add(1);
        }

        emit ReleasingGracePeriod(owner(), gracePeriodCurrent, block.number);
    }

    function withdraw() external {
        require(_msgSender() == beneficiary, "benificiary account only");
        payable(beneficiary).transfer(address(this).balance);
    }

    // royalties for Bloxes
    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external onlyOwner {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    function deleteDefaultRoyalty() external onlyOwner {
        _deleteDefaultRoyalty();
    }

     function setTokenRoyalty(
        uint256 tokenId,
        address receiver,
        uint96 feeNumerator
    ) external onlyOwner {
        _setTokenRoyalty(tokenId, receiver, feeNumerator);
    }

    function setContractURI(string memory _contractUri) external onlyOwner {
        contractUri = _contractUri;
    }

    function contractURI() public view returns (string memory) {
        return contractUri;
    }

    function setLandmarkNumber(uint256[] memory _bloxIds, bool _flag) external onlyOwner {
        for (uint i=0; i<_bloxIds.length; i++) {
            require(_bloxIds[i] <= bloxSupplyWithLandmark, "exceeding landmark index");
            isLandmark[_bloxIds[i]] = _flag;
        }
    }

    // baseURi overrider
    function _baseURI() internal view virtual override returns(string memory) {
        return baseURI;
    }

    function setCustomURI(string memory _newCustomURI) external onlyOwner {
        customURI = _newCustomURI;
    }

    function setBaseURI(string memory _newBaseURI) external onlyOwner {
        baseURI = _newBaseURI;
    }
    
    function setMinter(address _minter) external onlyOwner {
        minter = _minter;
    }

    function setCapper(address _capper) external onlyOwner {
        capper = _capper;
    }
}
