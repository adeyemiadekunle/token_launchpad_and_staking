// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/ITokenSaleCreator.sol";
import "./helpers/TransferHelper.sol";

contract TokenSaleCreator is
    ReentrancyGuard,
    Pausable,
    Ownable,
    AccessControl,
    ITokenSaleCreator
{
    using Address for address;
    using SafeMath for uint256;

    bytes32[] public allTokenSales;
    bytes32 public constant ADMIN_ROLE =
        keccak256(abi.encodePacked("ADMIN_ROLE"));
    bytes32 public constant PROJECT_OWNER_ROLE =
        keccak256("PROJECT_OWNER_ROLE");
    bytes32 public pauserRole = keccak256(abi.encodePacked("PAUSER_ROLE"));
    bytes32 public withdrawerRole =
        keccak256(abi.encodePacked("WITHDRAWER_ROLE"));
    bytes32 public finalizerRole =
        keccak256(abi.encodePacked("FINALIZER_ROLE"));
    uint256 public withdrawable;
    uint256 public feePercentage;
    mapping(bytes32 => TokenSaleItem) private tokenSales;
    mapping(bytes32 => uint256) private totalEtherRaised;
    mapping(bytes32 => mapping(address => bool))
        private isNotAllowedToContribute;
    mapping(bytes32 => mapping(address => uint256)) public amountContributed;
    mapping(bytes32 => mapping(address => uint256)) public balance;

    // Define a mapping to store contributors for each saleId
    mapping(bytes32 => Contributor[]) private contributorsMap;

    mapping(bytes32 => mapping(address => bool)) public whitelist;

    mapping(bytes32 => uint256) public availableTokensPerSale;

    // Declare a modifier that can be used to check if the parameters for a token sale
    modifier whenParamsSatisfied(bytes32 saleId) {
        TokenSaleItem memory tokenSale = tokenSales[saleId];
        require(!tokenSale.interrupted, "token_sale_paused");
        require(
            block.timestamp >= tokenSale.details.saleStartTime,
            "token_sale_not_started_yet"
        );
        require(!tokenSale.ended, "token_sale_has_ended");
        require(
            !isNotAllowedToContribute[saleId][_msgSender()],
            "you_are_not_allowed_to_participate_in_this_sale"
        );
        require(
            totalEtherRaised[saleId] < tokenSale.details.hardCap,
            "hardcap_reached"
        );
        _;
    }

    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, _msgSender()), "only_admin");
        _;
    }

    event ContributionMade(
        bytes32 indexed saleId,
        address indexed contributor,
        uint256 amount,
        uint256 tokens
    );

    /**
     * @dev Grants the pauserRole, withdrawerRole, and finalizerRole to the deployer.
     * @param _feePercentage The percentage of the token sale proceeds that will be taken as a fee.
     */
    constructor(uint256 _feePercentage, address initialOwner)
        Ownable(initialOwner)
    {
        // Grant the pauserRole to the deployer.
        _grantRole(pauserRole, _msgSender());

        // Grant the withdrawerRole to the deployer.
        _grantRole(withdrawerRole, _msgSender());

        // Grant the finalizerRole to the deployer.
        _grantRole(finalizerRole, _msgSender());

        // Set the fee percentage.
        feePercentage = _feePercentage;
    }

    function initTokenSale(
        TokenSaleDetails memory details // Pass the struct as argument
    )
        external
        whenNotPaused
        nonReentrant
        onlyRole(PROJECT_OWNER_ROLE)
        returns (bytes32 saleId)
    {
        require(
            details.saleStartTime > block.timestamp &&
                details.saleStartTime.sub(block.timestamp) >= 24 hours,
            "sale_must_begin_in_at_least_24_hours"
        );
        require(
            IERC20(details.token).allowance(_msgSender(), address(this)) >=
                details.tokensForSale,
            "not_enough_allowance_given"
        );
        TransferHelpers._safeTransferFromERC20(
            details.token,
            _msgSender(),
            address(this),
            details.tokensForSale
        );

        saleId = keccak256(
            abi.encodePacked(
                details.token,
                _msgSender(),
                block.timestamp,
                details.tokensForSale,
                details.hardCap,
                details.softCap,
                details.privatePresaleRate,
                details.publicPresaleRate,
                details.minContributionEther,
                details.maxContributionEther,
                details.saleStartTime,
                details.daysToLast,
                details.proceedsTo,
                details.refundable
            )
        );

        // Calculate end time outside the curly braces to avoid 'stack too deep' errors
        uint256 endTime = details.saleStartTime.add(
            details.daysToLast.mul(1 days)
        );
        availableTokensPerSale[saleId] = details.tokensForSale;

        tokenSales[saleId] = TokenSaleItem(
            details, // Use the provided details object
            false,
            false,
            endTime
        );

        allTokenSales.push(saleId);

        // Emit event using details from the struct
        emit TokenSaleItemCreated(saleId, details);

        return saleId;
    }

    // Function to contribute to a token sale
    function contribute(bytes32 saleId)
        external
        payable
        whenNotPaused
        nonReentrant
        whenParamsSatisfied(saleId)
    {
        TokenSaleItem storage tokenSaleItem = tokenSales[saleId];

        require(
            msg.value >= tokenSaleItem.details.minContributionEther &&
                msg.value <= tokenSaleItem.details.maxContributionEther,
            "contribution_must_be_within_min_and_max_range"
        );
        // Check if sale has ended due to end time OR reaching hard cap
        require(
            !tokenSaleItem.ended &&
                (block.timestamp <=
                    tokenSaleItem.details.saleStartTime.add(
                        tokenSaleItem.details.daysToLast.mul(1 days)
                    ) ||
                    totalEtherRaised[saleId] >= tokenSaleItem.details.hardCap),
            "sale_ended_or_hardcap_reached"
        );

        if (
            totalEtherRaised[saleId] >= tokenSaleItem.details.hardCap ||
            block.timestamp <=
            tokenSaleItem.details.saleStartTime.add(
                tokenSaleItem.details.daysToLast.mul(1 days)
            )
        ) {
            tokenSales[saleId].ended = true;
        }

        // Check for appropriate sale phase based on time
        if (block.timestamp <= tokenSaleItem.details.privateSaleEndTime) {
            require(
                isWhitelisted(msg.sender, saleId),
                "not_whitelisted_for_private_sale"
            );
        }

        uint256 presaleRate;
        if (block.timestamp <= tokenSaleItem.details.privateSaleEndTime) {
            presaleRate = tokenSaleItem.details.privatePresaleRate;
        } else {
            presaleRate = tokenSaleItem.details.publicPresaleRate;
        }

        uint256 val = presaleRate.mul(msg.value).div(1 ether);

        require(
            availableTokensPerSale[saleId] >= val,
            "tokens_available_for_sale_is_less"
        );

        // Add contributor to contributorsMap
        addContributor(saleId, _msgSender(), msg.value);

        balance[saleId][_msgSender()] = balance[saleId][_msgSender()].add(val);
        amountContributed[saleId][_msgSender()] = amountContributed[saleId][
            _msgSender()
        ].add(msg.value);
        totalEtherRaised[saleId] = totalEtherRaised[saleId].add(msg.value);
        availableTokensPerSale[saleId] = availableTokensPerSale[saleId].sub(
            val
        );
        emit ContributionMade(saleId, msg.sender, msg.value, val);
    }

    function addContributor(
        bytes32 saleId,
        address contributor,
        uint256 amount
    ) private {
        contributorsMap[saleId].push(Contributor(contributor, amount));
    }

    // Function to withdraw tokens from a sale that has ended or reached its end time.
    function normalWithdrawal(bytes32 saleId)
        external
        whenNotPaused
        nonReentrant
    {
        TokenSaleItem storage tokenSaleItem = tokenSales[saleId];
        require(
            tokenSaleItem.ended ||
                block.timestamp >= tokenSaleItem.details.daysToLast,
            "sale_has_not_ended"
        );
        TransferHelpers._safeTransferERC20(
            tokenSaleItem.details.token,
            _msgSender(),
            balance[saleId][_msgSender()]
        );
        delete balance[saleId][_msgSender()];
    }

    // Function to withdraw funds in case of an emergency
    function emergencyWithdrawal(bytes32 saleId) external nonReentrant {
        TokenSaleItem storage tokenSaleItem = tokenSales[saleId];
        require(!tokenSaleItem.ended, "sale_has_already_ended");
        TransferHelpers._safeTransferEther(
            _msgSender(),
            amountContributed[saleId][_msgSender()]
        );

        // Update available tokens using the mapping
        availableTokensPerSale[saleId] = availableTokensPerSale[saleId].add(
            balance[saleId][_msgSender()]
        );

        totalEtherRaised[saleId] = totalEtherRaised[saleId].sub(
            amountContributed[saleId][_msgSender()]
        );
        delete balance[saleId][_msgSender()];
        delete amountContributed[saleId][_msgSender()];
    }

    // Function to pause the Sales
    function interrupTokenSale(bytes32 saleId)
        external
        whenNotPaused
        onlyOwner
    {
        TokenSaleItem storage tokenSale = tokenSales[saleId];
        require(!tokenSale.ended, "token_sale_has_ended");
        tokenSale.interrupted = true;
    }

    // Function to resume the Sales
    function uninterrupTokenSale(bytes32 saleId)
        external
        whenNotPaused
        onlyOwner
    {
        TokenSaleItem storage tokenSale = tokenSales[saleId];
        tokenSale.interrupted = false;
    }

    // Function to finalize the Token sales
    function finalizeTokenSale(bytes32 saleId) external whenNotPaused {
        if (
            tokenSales[saleId].ended && // Check if sale has ended
            totalEtherRaised[saleId] < tokenSales[saleId].details.softCap && // Soft cap not reached
            tokenSales[saleId].details.refundable // Refunds enabled
        ) {
            // Initiate refund process
            initiateRefunds(saleId);
        } else {
            TokenSaleItem storage tokenSale = tokenSales[saleId];
            require(
                hasRole(finalizerRole, _msgSender()) ||
                    tokenSale.details.admin == _msgSender(),
                "only_finalizer_or_admin"
            );
            require(!tokenSale.ended, "sale_has_ended");
            uint256 platformFees = (totalEtherRaised[saleId] * feePercentage)
                .div(100);
            TransferHelpers._safeTransferEther(
                tokenSale.details.proceedsTo,
                totalEtherRaised[saleId] - platformFees
            );
            withdrawable = withdrawable.add(platformFees);

            if (availableTokensPerSale[saleId] > 0) {
                // Log unsold tokens for transparency

                // Transfer unsold tokens to designated recipient
                TransferHelpers._safeTransferERC20(
                    tokenSale.details.token,
                    tokenSale.details.proceedsTo,
                    availableTokensPerSale[saleId]
                );

                // Reset available tokens for the saleId
                availableTokensPerSale[saleId] = 0;
            }

            tokenSale.ended = true;
        }
    }

    // Bar from participatinn
    function barFromParticiption(bytes32 saleId, address account) external {
        TokenSaleItem memory tokenSale = tokenSales[saleId];
        require(tokenSale.details.admin == _msgSender(), "only_admin");
        require(!tokenSale.ended, "sale_has_ended");
        require(!isNotAllowedToContribute[saleId][account], "already_barred");
        isNotAllowedToContribute[saleId][account] = true;
    }

    function rescindBar(bytes32 saleId, address account) external {
        TokenSaleItem memory tokenSale = tokenSales[saleId];
        require(tokenSale.details.admin == _msgSender(), "only_admin");
        require(!tokenSale.ended, "sale_has_ended");
        require(isNotAllowedToContribute[saleId][account], "not_barred");
        isNotAllowedToContribute[saleId][account] = false;
    }

    // Function to initial refund

    function initiateRefunds(bytes32 saleId) private {
        Contributor[] memory contributors = contributorsMap[saleId];
        for (uint256 i = 0; i < contributors.length; i++) {
            address contributor = contributors[i].contributorAddress;
            uint256 amount = contributors[i].amountContributed;
            TransferHelpers._safeTransferEther(contributor, amount);
        }
    }

    function cancelSale(bytes32 saleId) external onlyOwner {
        require(!tokenSales[saleId].ended, "sale_already_ended");
        tokenSales[saleId].ended = true;
        initiateRefunds(saleId); // initiate refunds if applicable
    }

    // Function to get all contributors for a specific saleId
    function getContributors(bytes32 saleId)
        public
        view
        returns (address[] memory)
    {
        uint256 length = contributorsMap[saleId].length;
        address[] memory contributors = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            contributors[i] = contributorsMap[saleId][i].contributorAddress;
        }
        return contributors;
    }

    // Function to get the contributed amount for a specific contributor in a saleId
    function getContributedAmount(bytes32 saleId, address contributor)
        public
        view
        returns (uint256)
    {
        Contributor[] memory contributors = contributorsMap[saleId];
        for (uint256 i = 0; i < contributors.length; i++) {
            if (contributors[i].contributorAddress == contributor) {
                return contributors[i].amountContributed;
            }
        }
        return 0; // Return 0 if the contributor is not found
    }

    function addToWhitelist(bytes32 saleId, address[] calldata addresses)
        public
        onlyOwner
    {
        for (uint256 i = 0; i < addresses.length; i++) {
            whitelist[saleId][addresses[i]] = true;
        }
    }

    function isWhitelisted(address user, bytes32 saleId)
        public
        view
        returns (bool)
    {
        return whitelist[saleId][user];
    }

    function removeFromWhitelist(bytes32 saleId, address[] calldata addresses)
        public
        onlyOwner
    {
        for (uint256 i = 0; i < addresses.length; i++) {
            whitelist[saleId][addresses[i]] = false;
        }
    }

    function getAvailableTokens(bytes32 saleId) public view returns (uint256) {
        // Retrieve available tokens from the mapping
        return availableTokensPerSale[saleId];
    }

    function pause() external whenNotPaused {
        require(hasRole(pauserRole, _msgSender()), "must_have_pauser_role");
        _pause();
    }

    function unpause() external whenPaused {
        require(hasRole(pauserRole, _msgSender()), "must_have_pauser_role");
        _unpause();
    }

    function getTotalEtherRaisedForSale(bytes32 saleId)
        external
        view
        returns (uint256)
    {
        return totalEtherRaised[saleId];
    }

    function getExpectedEtherRaiseForSale(bytes32 saleId)
        external
        view
        returns (uint256)
    {
        TokenSaleItem memory tokenSaleItem = tokenSales[saleId];
        return tokenSaleItem.details.hardCap;
    }

    function getSoftCap(bytes32 saleId) external view returns (uint256) {
        TokenSaleItem memory tokenSaleItem = tokenSales[saleId];
        return tokenSaleItem.details.softCap;
    }

    function withdrawProfit(address to) external {
        require(hasRole(withdrawerRole, _msgSender()), "only_withdrawer");
        TransferHelpers._safeTransferEther(to, withdrawable);
        withdrawable = 0;
    }

    receive() external payable {
        withdrawable = withdrawable.add(msg.value);
    }
}
