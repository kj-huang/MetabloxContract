// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721RoyaltyUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "../storage/PropertyTier.sol";
import "../storage/PropertyLevel.sol";

import "./MetabloxMemory.sol";

contract MetabloxEverywhere is
    ERC721RoyaltyUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    /* libs */
    using SafeERC20Upgradeable for ERC20Upgradeable;
    using SafeMathUpgradeable for uint8;
    using SafeMathUpgradeable for uint16;
    using SafeMathUpgradeable for uint256;
    using StringsUpgradeable for uint256;
    using CountersUpgradeable for CountersUpgradeable.Counter;

    CountersUpgradeable.Counter private _tokenIdCounter;

    /* Blox structure */
    struct Blox {
        bool registered;
        /* metadata */
        uint16 bloxSupply;
        string uriSuffix;
        uint16[] bloxNumbers;
        // mappings: blox number to whichever
        mapping(uint16 => address) owners;
        mapping(uint16 => bool) cappedBlox;
        mapping(uint16 => bool) isLandmark;
        // mint limitations
        bool allBloxSold;
        uint8 maxPublicMint;
        uint8 maxCustodialMint;
        // authorizies
        // consider using universal one
        // some members for GP.
        bool enabledGP;
        uint8 currPhase;
        uint8 remainingGP;
        // [WIP] Miscs
        bool enabledPublicMint;
    }

    struct TokenToBlox {
        bytes bloxIdentifier;
        uint16 bloxNumber;
    }
    /* Blox registry */
    // bytes(country_state_city) -> blox
    mapping(bytes => Blox) bloxRegistry;
    // token id -> blox identifier -> blox number
    mapping(uint256 => TokenToBlox) tokenToBloxRegistry;
    /* chainlink registration table */
    mapping(address => bool) public paymentTokenRegistry;
    // erc20 addr -> oracal address
    mapping(address => address) public priceFeedRegistry;
    // uris
    string public contractURI;
    string public baseURI;
    // global ahthorities
    address public minter;
    address public capper;
    address public paymentTokenBeneficiary; // for royalty as well
    /* tolerances */
    uint256 constant BASE_TOLERANCE = 1e4; // tolerance decimals: 4
    uint256 constant TOLERANCE_PADDING = 1e22; // 100 matic
    /* public params */
    address public propertyTierContractAddress;
    address public propertyLevelContractAddress;
    address public memoryContractAddress;

    string private constant DEFAULT_URI_SUFFIX = "global/";
    address private WMATIC_ADDRESS;

    mapping(uint256 => uint16) public tokenToBloxNumber;
    /* private params */
    /// @custom:oz-upgrades-unsafe-allow constructor
    // constructor() initializer {}

    event NewCityRegistered(string _country, string _state, string _city);
    event NewBloxAssociated(
        address indexed _user,
        uint256 indexed _tokenId,
        bytes _idetifier,
        uint256 _bloxNumber
    );

    event NewBloxMinted(
        address indexed _user,
        uint256 indexed tokenId,
        uint256 indexed _bloxNumber,
        bytes _identifier
    );

    event EnteringGracePeriod(
        address indexed _addr,
        uint256 _gracePeriod,
        uint256 _timestamp
    );

    event ReleasingGracePeriod(
        address indexed _addr,
        uint256 _gracePeriod,
        uint256 _timestamp
    );

    enum MintFlag {
        CUSTODIAL,
        PUBLIC
    }

    function initialize(
        address _propertyTierContractAddress,
        address _propertyLevelContractAddress,
        address _memoryContractAddress,
        address[] memory _tokenRelatedAddresses,
        address[] memory _authorities
    ) public initializer {
        __ERC721_init("Metablox", "Blox");
        __ERC721Royalty_init();
        __Ownable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        // initialize Metablox Everwhere contract
        __Blox_init(
            _propertyTierContractAddress,
            _propertyLevelContractAddress,
            _memoryContractAddress,
            _tokenRelatedAddresses,
            _authorities
        );
    }

    function __Blox_init(
        address _propertyTierContractAddress,
        address _propertyLevelContractAddress,
        address _memoryContractAddress,
        address[] memory _tokenRelatedAddresses,
        address[] memory _authorities
    ) internal {
        propertyTierContractAddress = _propertyTierContractAddress;
        propertyLevelContractAddress = _propertyLevelContractAddress;
        memoryContractAddress = _memoryContractAddress;

        address _usdt = _tokenRelatedAddresses[0];
        address _wmatic = _tokenRelatedAddresses[1];
        address _weth = _tokenRelatedAddresses[2];
        // USDT
        paymentTokenRegistry[_usdt] = true;
        // WMATIC
        paymentTokenRegistry[_wmatic] = true;
        // WETH
        paymentTokenRegistry[_weth] = true;

        priceFeedRegistry[_wmatic] = address(_tokenRelatedAddresses[3]);
        priceFeedRegistry[_weth] = address(_tokenRelatedAddresses[4]);

        minter = _authorities[0];
        capper = _authorities[1];
        paymentTokenBeneficiary = _authorities[2];

        WMATIC_ADDRESS = _wmatic;
    }

    modifier onlyMinter() {
        require(minter == _msgSender(), "caller is not the minter");
        _;
    }

    function getBlox(
        bytes memory _identifier
    ) private view returns (Blox storage) {
        return bloxRegistry[_identifier];
    }

    function register(
        string memory _country,
        string memory _state,
        string memory _city,
        string memory _uriSuffix
    ) external onlyOwner {
        // add blox into mapping
        bytes memory _identifier = getIdentifier(_country, _state, _city);
        require(!bloxRegistry[_identifier].registered, "Blox registered");
        // init blox data
        initBlox(_identifier, _uriSuffix);
        // fire event
        emit NewCityRegistered(_country, _state, _city);
    }

    function getIdentifier(
        string memory _country,
        string memory _state,
        string memory _city
    ) public pure returns (bytes memory) {
        return abi.encodePacked(_country, _state, _city);
    }

    function getBloxByTokenId(
        uint256 _tokenId
    )
        public
        view
        returns (
            address _bloxOwner,
            bytes memory _bloxIdentifier,
            uint256 _bloxNumber
        )
    {
        TokenToBlox memory _ttb = tokenToBloxRegistry[_tokenId];
        _bloxOwner = bloxRegistry[_ttb.bloxIdentifier].owners[_ttb.bloxNumber];
        _bloxIdentifier = _ttb.bloxIdentifier;
        _bloxNumber = _ttb.bloxNumber;
    }

    function getCity(
        bytes memory _identifier
    ) public pure returns (string memory _city) {
        _city = string(_identifier);
    }

    function getBloxTotalSupply(
        bytes memory _identifier
    ) public view returns (uint256) {
        return getBlox(_identifier).bloxNumbers.length;
    }

    function initBlox(
        bytes memory _identifier,
        string memory _uriSuffix
    ) private {
        // init a blank Blox
        Blox storage _blox = bloxRegistry[_identifier];
        _blox.registered = true;
        // set defaulte mint amount
        _blox.maxCustodialMint = 20;
        _blox.maxPublicMint = 5;
        // uri suffix
        _blox.uriSuffix = _uriSuffix;

        _blox.currPhase = 1;

        _blox.enabledPublicMint = true;
    }

    function capBlox(
        bytes memory _identifier,
        uint16[] memory _bloxNumbers,
        bool _flag
    ) external {
        require(capper == _msgSender(), "caller isn't capper");
        Blox storage _blox = getBlox(_identifier);
        for (uint256 i = 0; i < _bloxNumbers.length; i++) {
            _blox.cappedBlox[_bloxNumbers[i]] = _flag;
        }
    }

    function setBloxSupply(
        bytes memory _identifier,
        uint16 _bloxSupply
    ) external onlyOwner {
        Blox storage _blox = getBlox(_identifier);
        _blox.bloxSupply = _bloxSupply;
    }

    function getBloxSupply(
        bytes memory _identifier
    ) external view returns (uint16) {
        Blox storage _blox = getBlox(_identifier);
        return _blox.bloxSupply;
    }

    function initBloxPropertyLevel(uint256 _tokenId) private {
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

        PropertyLevel(propertyLevelContractAddress).batchAttach(
            _tokenId,
            _attrIds,
            _attrAmounts,
            _texts
        );
    }

    function authorizedGlobalMint(
        address _user,
        uint256 _mintAmount,
        uint16[] calldata _blockNumbers
    ) external onlyMinter whenNotPaused {
        globalMint(_user, _mintAmount, _blockNumbers);
    }

    function authorizedAssociation(
        bytes memory _identifier,
        uint256[] memory _globalTokenIds,
        uint16[] memory _bloxNumbers
    ) external onlyMinter whenNotPaused {
        associateTokenToBlox(
            _identifier,
            _globalTokenIds,
            _bloxNumbers,
            MintFlag.CUSTODIAL
        );
    }

    function globalMint(
        address _user,
        uint256 _mintAmount,
        uint16[] memory _blockNumbers
    ) private returns (uint256[] memory) {
        require(
            _mintAmount > 0 && _mintAmount <= 20,
            "exceed global mint range"
        );

        require(
            _blockNumbers.length == _mintAmount,
            "BlockNumbers' length isn't match with mint amount"
        );

        uint256[] memory _tokenIds = new uint256[](_mintAmount);
        for (uint256 i = 0; i < _mintAmount; i++) {
            uint256 _tokenId = _tokenIdCounter.current();
            _safeMint(_user, _tokenId);

            _tokenIdCounter.increment();
            _tokenIds[i] = _tokenId;

            tokenToBloxNumber[_tokenId] = _blockNumbers[i];
        }

        return _tokenIds;
    }

    function associateTokenToBlox(
        bytes memory _identifier,
        uint256[] memory _globalTokenIds,
        uint16[] memory _bloxNumbers,
        MintFlag _FLAG
    ) private {
        require(
            _globalTokenIds.length > 0 && _globalTokenIds.length <= 20,
            "exceed association range"
        );
        require(
            _globalTokenIds.length == _bloxNumbers.length,
            "unmatched length"
        );

        Blox storage _blox = getBlox(_identifier);
        require(
            _bloxNumbers.length + _blox.bloxNumbers.length <= _blox.bloxSupply,
            "exceed blox supply"
        );

        for (uint256 i = 0; i < _globalTokenIds.length; i++) {
            uint16 _bloxNumber = _bloxNumbers[i];
            require(
                _bloxNumber >= 1 && _bloxNumber <= _blox.bloxSupply,
                "invalid blox number"
            );
            require(_blox.owners[_bloxNumber] == address(0), "blox is owned");
            if (_FLAG == MintFlag.PUBLIC) {
                require(!_blox.cappedBlox[_bloxNumber], "blox is capped");
            }
            require(!_blox.isLandmark[_bloxNumber], "blox is a landmark");
            uint256 _tokenId = _globalTokenIds[i];
            address _user = ownerOf(_tokenId);

            tokenToBloxRegistry[_tokenId] = TokenToBlox({
                bloxIdentifier: _identifier,
                bloxNumber: _bloxNumber
            });

            _blox.owners[_bloxNumber] = _user;
            _blox.bloxNumbers.push(_bloxNumber);

            if (_blox.bloxNumbers.length == _blox.bloxSupply) {
                _blox.allBloxSold = true;
            }
            initBloxPropertyLevel(_globalTokenIds[i]);

            gracePeriodCheck(_blox, _user);

            emit NewBloxAssociated(_user, _tokenId, _identifier, _bloxNumber);
        }
    }

    // custodial batch mint
    function custodialBatchMint(
        bytes memory _identifier,
        address _user,
        uint16[] memory _bloxNumbers
    ) external onlyMinter whenNotPaused {
        Blox storage _blox = getBlox(_identifier);
        require(_blox.registered, "not a registered blox");
        // check blox length availability
        require(
            _bloxNumbers.length <= _blox.maxCustodialMint &&
                _bloxNumbers.length > 0,
            "exceed maximum mint amount"
        );
        // check if the mint amount exceeds max blox supply
        uint256 _supply = _blox.bloxNumbers.length;
        require(
            _supply + _bloxNumbers.length <= _blox.bloxSupply,
            "exceed maximum blox supply"
        );
        // mint execution
        uint256[] memory _globalTokenIds = globalMint(
            _user,
            _bloxNumbers.length,
            _bloxNumbers
        );
        associateTokenToBlox(
            _identifier,
            _globalTokenIds,
            _bloxNumbers,
            MintFlag.CUSTODIAL
        );
    }

    // reservation batch mint
    function publicBatchMint(
        bytes memory _identifier,
        uint16[] memory _bloxNumbers,
        uint8[] memory _propertyTiers,
        address _paymentToken,
        uint256[] memory _erc20TokenAmounts,
        uint256 _tolerance
    ) public payable nonReentrant whenNotPaused {
        // should be in payment token registry
        require(paymentTokenRegistry[_paymentToken], "invalid payment token");

        uint8 currPhase = 1;
        uint8 remainingGP = 0;
       
        Blox storage _blox = getBlox(_identifier);
        if (_blox.registered) {
            // check public mint flipper
            require(
                _blox.enabledPublicMint,
                "public mint disabled temporarily"
            );
            // check blox length availability
            require(
                _bloxNumbers.length <= _blox.maxPublicMint &&
                    _bloxNumbers.length > 0,
                "exceed maximum mint amount"
            );
            // check blox length availability
            require(
                _bloxNumbers.length == _propertyTiers.length &&
                    _propertyTiers.length == _erc20TokenAmounts.length,
                "unmatched length of array"
            );
            // check if the mint amount exceeds max blox supply
            uint256 _supply = _blox.bloxNumbers.length;
            require(
                _supply + _bloxNumbers.length <= _blox.bloxSupply,
                "exceed maximum blox supply"
            );

            currPhase = _blox.currPhase;
            remainingGP = _blox.remainingGP;

            
        }

        // check ayment availability
        uint256 _totalPaymentAmount = 0;
        for (uint256 i = 0; i < _bloxNumbers.length; i++) {
            require(
                isAbleToMintWith(
                    priceFeedRegistry[_paymentToken],
                    _erc20TokenAmounts[i],
                    _tolerance,
                    _propertyTiers[i],
                    currPhase,
                    remainingGP
                ),
                string(abi.encodePacked("unable to mint with", _paymentToken))
            );
            _totalPaymentAmount += _erc20TokenAmounts[i];
        }
        // matic special examination
        if (_paymentToken == WMATIC_ADDRESS) {
            require(
                msg.value >= _totalPaymentAmount,
                "insufficient matic amount to mint"
            );
        } else {
            ERC20Upgradeable _erc20 = ERC20Upgradeable(_paymentToken);
            _erc20.safeTransferFrom(
                _msgSender(),
                paymentTokenBeneficiary,
                _totalPaymentAmount
            );
        }

         // payment succeeded, execute mint
        uint256[] memory _globalTokenIds = globalMint(
            _msgSender(),
            _bloxNumbers.length,
            _bloxNumbers
        );

        if (_blox.registered) {
            associateTokenToBlox(
                _identifier,
                _globalTokenIds,
                _bloxNumbers,
                MintFlag.PUBLIC
            );
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
    function isAbleToMintWith(
        address priceFeedAddress,
        uint256 tokenAmount,
        uint256 tolerance,
        uint8 propertyTier,
        uint8 _currPhase,
        uint256 _remainingGP
    ) private view returns (bool) {
        // chainlink: 18 + 8 = 0 + 4 + 22
        uint256 bloxPriceInUsdt = getPhasePrice(
            _currPhase,
            _remainingGP,
            propertyTier
        );
        uint256 usdPrice = getUsdPrice(priceFeedAddress);
        if (
            (tokenAmount * usdPrice) >
            bloxPriceInUsdt * (BASE_TOLERANCE + tolerance) * TOLERANCE_PADDING
        ) revert("exceed tolerance range");
        if (
            (tokenAmount * usdPrice) <
            bloxPriceInUsdt * (BASE_TOLERANCE - tolerance) * TOLERANCE_PADDING
        ) revert("below tolerance range");

        return true;
    }

    function gracePeriodCheck(Blox storage _blox, address _user) private {
        // if the reserved supply hit a specific ratio
        // grace period activates
        if (_blox.currPhase >= 10) {
            return;
        }

        if (!_blox.enabledGP) {
            return;
        }
        uint256 _supply = _blox.bloxNumbers.length;
        if (_supply % getBloxSupplyDivBy10(_blox.bloxSupply) == 0) {
            _blox.currPhase = _blox.currPhase + 1;
            _blox.remainingGP = _blox.remainingGP + 1;
            emit EnteringGracePeriod(_user, _blox.remainingGP, block.number);
        }
    }

    function releaseGracePeriod(bytes memory _identifier) external onlyOwner {
        Blox storage _blox = getBlox(_identifier);

        (bool _canSub, ) = _blox.remainingGP.trySub(1);
        require(_canSub, "GP remaining overflow");

        _blox.remainingGP = _blox.remainingGP - 1;
        emit ReleasingGracePeriod(owner(), _blox.remainingGP, block.number);
    }

    function getUsdPrice(address poolAddress) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(poolAddress);
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return uint256(price);
    }

    function getPhasePrice(
        uint8 _currPhase,
        uint256 _remainingGP,
        uint8 propertyTier
    ) public view returns (uint256) {
        return 100;
        // bool _canSub;
        // uint256 _phase;
        // uint256 _propertyTier;
        // (_canSub, _phase) = _currPhase.trySub(_remainingGP);
        // (_canSub, _propertyTier) = propertyTier.trySub(1);
        // require(
        //     _canSub,
        //     "phase or property tier overflow when getting base price"
        // );

        // return
        //     PropertyTier(propertyTierContractAddress).getBloxBasePrice(
        //         _phase,
        //         _propertyTier
        //     );
    }

    function getBloxSupplyDivBy10(
        uint256 _bloxSupply
    ) internal pure returns (uint256) {
        (bool _canDiv, uint256 _divided) = _bloxSupply.tryDiv(10);
        require(_canDiv, "when getting divided supply");
        return _divided;
    }

    function addNewPriceFeed(
        address _erc20Addr,
        address _priceFeedAddr
    ) external onlyOwner {
        priceFeedRegistry[_erc20Addr] = _priceFeedAddr;
    }

    function isApprovedForAll(
        address _owner,
        address _operator
    ) public view override(ERC721Upgradeable) returns (bool isOperator) {
        // if OpenSea's ERC721 Proxy Address is detected, auto-return true
        if (_operator == address(0x58807baD0B376efc12F5AD86aAc70E78ed67deaE))
            return true;

        // otherwise, use the default ERC721.isApprovedForAll()
        return super.isApprovedForAll(_owner, _operator);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    // The following functions are overrides required by Solidity.
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721Upgradeable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function tokenURI(
        uint256 _tokenId
    ) public view override(ERC721Upgradeable) returns (string memory) {
        super.tokenURI(_tokenId);
        TokenToBlox memory _ttb = tokenToBloxRegistry[_tokenId];
        return
            bytes(baseURI).length > 0 && _ttb.bloxNumber != 0
                ? string(
                    abi.encodePacked(
                        baseURI,
                        bloxRegistry[_ttb.bloxIdentifier].uriSuffix,
                        uint256(_ttb.bloxNumber).toString()
                    )
                )
                : string(
                    abi.encodePacked(
                        baseURI,
                        DEFAULT_URI_SUFFIX,
                        _tokenId.toString()
                    )
                );
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721RoyaltyUpgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function withdraw() external onlyOwner {
        payable(paymentTokenBeneficiary).transfer(address(this).balance);
    }

    // royalties for Bloxes
    function setDefaultRoyalty(
        address receiver,
        uint96 feeNumerator
    ) external onlyOwner {
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

    function setContractURI(string memory _contractURI) external onlyOwner {
        contractURI = _contractURI;
    }

    function setLandmarkNumber(
        bytes memory _identifier,
        uint16[] memory _bloxNumbers,
        bool _flag
    ) external onlyOwner {
        Blox storage _blox = getBlox(_identifier);
        for (uint256 i = 0; i < _bloxNumbers.length; i++) {
            require(_bloxNumbers[i] <= _blox.bloxSupply, "exceeding index");
            _blox.isLandmark[_bloxNumbers[i]] = _flag;
        }
    }

    function getGracePeriod(
        bytes memory _identifier
    ) public view returns (uint256 _currPhase, uint256 _remainingGP) {
        Blox storage _blox = bloxRegistry[_identifier];
        _currPhase = _blox.currPhase;
        _remainingGP = _blox.remainingGP;
    }

    // baseURi overrider
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string memory _newBaseURI) external onlyOwner {
        baseURI = _newBaseURI;
    }

    function setPropertyLevelContract(address _new) external onlyOwner {
        propertyLevelContractAddress = _new;
    }

    function setMemoryContract(address _new) external onlyOwner {
        memoryContractAddress = _new;
    }

    function flipGracePeriod(
        bytes memory _identifier,
        bool _enabledGP
    ) external onlyOwner {
        Blox storage _blox = getBlox(_identifier);
        _blox.enabledGP = _enabledGP;
    }

    function flipPublicMint(
        bytes memory _identifier,
        bool _enabledPublicMint
    ) external onlyOwner {
        Blox storage _blox = getBlox(_identifier);
        _blox.enabledPublicMint = _enabledPublicMint;
    }

    function _burn(
        uint256 tokenId
    ) internal override(ERC721RoyaltyUpgradeable) {
        super._burn(tokenId);
    }

    function totalSupply() public view returns (uint256) {
        return _tokenIdCounter.current();
    }

    function setCapper(address _capper) public onlyOwner {
        capper = _capper;
    }

    function setMinter(address _minter) public onlyOwner {
        minter = _minter;
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        super.transferFrom(from, to, tokenId);

        TokenToBlox memory _ttb = tokenToBloxRegistry[tokenId];
        if (_ttb.bloxNumber != 0) {
            Blox storage _blox = bloxRegistry[_ttb.bloxIdentifier];
            _blox.owners[_ttb.bloxNumber] = to;
        }
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public virtual override {
        super.safeTransferFrom(from, to, tokenId, data);

        TokenToBlox memory _ttb = tokenToBloxRegistry[tokenId];
        if (_ttb.bloxNumber != 0) {
            Blox storage _blox = bloxRegistry[_ttb.bloxIdentifier];
            _blox.owners[_ttb.bloxNumber] = to;
        }
    }
}
