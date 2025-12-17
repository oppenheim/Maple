// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.7 ^0.8.7;

// modules/withdrawal-manager-queue/contracts/interfaces/IMapleWithdrawalManagerStorage.sol

interface IMapleWithdrawalManagerStorage {

    /**
     *  @dev    Returns the address of the pool contract.
     *  @return pool Address of the pool contract.
     */
    function pool() external view returns (address pool);

    /**
     *  @dev    Returns the address of the pool manager contract.
     *  @return poolManager Address of the pool manager contract.
     */
    function poolManager() external view returns (address poolManager);

    /**
     *  @dev    Returns the total amount of shares pending redemption.
     *  @return totalShares Total amount of shares pending redemption.
     */
    function totalShares() external view returns (uint256 totalShares);

    /**
     *  @dev    Checks if an account is set to perform withdrawals manually.
     *  @param  account  Address of the account.
     *  @return isManual `true` if the account withdraws manually, `false` if not.
     */
    function isManualWithdrawal(address account) external view returns (bool isManual);

    /**
     *  @dev    Returns the amount of shares available for manual withdrawal.
     *  @param  owner           The address of the owner of shares.
     *  @return sharesAvailable Amount of shares available for manual withdrawal.
     */
    function manualSharesAvailable(address owner) external view returns (uint256 sharesAvailable);

    /**
     *  @dev    Returns the amount of shares escrowed for a specific user yet to be processed.
     *  @param  owner          The address of the owner of shares.
     *  @return escrowedShares Amount of shares escrowed for the user.
     */
    function userEscrowedShares(address owner) external view returns (uint256 escrowedShares);

    /**
     *  @dev    Returns the first and last withdrawal requests pending redemption.
     *  @return nextRequestId Identifier of the next withdrawal request that will be processed.
     *  @return lastRequestId Identifier of the last created withdrawal request.
     */
    function queue() external view returns (uint128 nextRequestId, uint128 lastRequestId);
    
}

// modules/withdrawal-manager-queue/contracts/interfaces/Interfaces.sol

interface IERC20Like_0 {

    function balanceOf(address account_) external view returns (uint256 balance_);

}

interface IGlobalsLike {

    function canDeploy(address caller_) external view returns (bool canDeploy_);

    function isFunctionPaused(bytes4 sig_) external view returns (bool isFunctionPaused_);

    function governor() external view returns (address governor_);

    function isInstanceOf(bytes32 instanceId, address instance_) external view returns (bool isInstance_);

    function isValidScheduledCall(
        address caller_,
        address contract_,
        bytes32 functionId_,
        bytes calldata callData_
    ) external view returns (bool isValid_);

    function operationalAdmin() external view returns (address operationalAdmin_);

    function securityAdmin() external view returns (address securityAdmin_);

    function unscheduleCall(address caller_, bytes32 functionId_, bytes calldata callData_) external;

}

interface IMapleProxyFactoryLike {

    function isInstance(address instance_) external view returns (bool isInstance_);

    function mapleGlobals() external returns (address globals_);

}

interface IPoolLike {

    function asset() external view returns (address asset_);

    function manager() external view returns (address poolManager_);

    function previewRedeem(uint256 shares_) external view returns (uint256 assets_);

    function redeem(uint256 shares_, address receiver_, address owner_) external returns (uint256 assets_);

    function totalSupply() external view returns (uint256 totalSupply_);

}

interface IPoolManagerLike {

    function factory() external view returns (address factory_);

    function poolDelegate() external view returns (address poolDelegate_);

    function totalAssets() external view returns (uint256 totalAssets_);

    function unrealizedLosses() external view returns (uint256 unrealizedLosses_);

}

// modules/withdrawal-manager-queue/contracts/utils/SortedLinkedList.sol

library SortedLinkedList {

    struct Node {
        uint128 next;
        uint128 prev;
        bool exists;
    }

    struct List {
        uint128 head;
        uint128 tail;
        uint256 size;

        mapping(uint128 => Node) nodes;
    }

    /**************************************************************************************************************************************/
    /*** Write Functions                                                                                                                ***/
    /**************************************************************************************************************************************/

    /**
     * @dev   Pushes a value to the list.
     *        It is expected that the value is biggest so far so it will be added at the end of the list.
     * @param list   The list to push the value to.
     * @param value_ The value to push to the list.
     */
    function push(List storage list, uint128 value_) internal {
        uint128 tail_ = list.tail;

        require(value_ > 0,              "SLL:P:ZERO_VALUE");
        require(!contains(list, value_), "SLL:P:VALUE_EXISTS");
        require(value_ > tail_,          "SLL:P:NOT_LARGEST");

        list.nodes[value_] = Node({
            next:   0,
            prev:   tail_,
            exists: true
        });

        if (tail_ != 0) {
            list.nodes[tail_].next = value_;
        }

        list.tail = value_;

        if (list.head == 0) {
            list.head = value_;
        }

        list.size++;
    }

    /**
     * @dev   Removes a value from the list in O(1) time.
     * @param list   The list to remove the value from.
     * @param value_ The value to remove from the list.
     */
    function remove(List storage list, uint128 value_) internal {
        require(contains(list, value_), "SLL:R:VALUE_NOT_EXISTS");

        uint128 prev_ = list.nodes[value_].prev;
        uint128 next_ = list.nodes[value_].next;

        if (prev_ != 0) {
            list.nodes[prev_].next = next_;
        } else {
            list.head = next_;
        }

        if (next_ != 0) {
            list.nodes[next_].prev = prev_;
        } else {
            list.tail = prev_;
        }

        delete list.nodes[value_];
        list.size--;
    }

    /**************************************************************************************************************************************/
    /*** View Functions                                                                                                                 ***/
    /**************************************************************************************************************************************/

    /**
     * @dev    Gets the length of the list.
     * @param  list    The list to get the length of.
     * @return length_ The length of the list.
     */
    function length(List storage list) internal view returns (uint256 length_) {
        length_ = list.size;
    }

    /**
     * @dev    Gets all values from the list.
     * @param  list    The list to get the values from.
     * @return values_ All values from the list.
     */
    function getAllValues(List storage list) internal view returns (uint128[] memory values_) {
        values_ = new uint128[](list.size);

        uint128 current_ = list.head;
        uint256 size_    = list.size;

        for (uint256 i = 0; i < size_; i++) {
            values_[i] = current_;
            current_   = list.nodes[current_].next;
        }
    }

    /**
     * @dev    Gets the last value in the list.
     * @param  list   The list to get the last value from.
     * @return value_ The last value in the list.
     */
    function getLast(List storage list) internal view returns (uint128 value_) {
        value_ = list.tail;
    }

    /**
     * @dev    Checks if a value exists in the list.
     * @param  list    The list to check.
     * @param  value_  The value to check for.
     * @return exists_ True if the value exists in the list.
     */
    function contains(List storage list, uint128 value_) internal view returns (bool exists_) {
        exists_ = list.nodes[value_].exists;
    }

}

// modules/withdrawal-manager-queue/modules/erc20-helper/src/interfaces/IERC20Like.sol

/// @title Interface of the ERC20 standard as needed by ERC20Helper.
interface IERC20Like_1 {

    function approve(address spender_, uint256 amount_) external returns (bool success_);

    function transfer(address recipient_, uint256 amount_) external returns (bool success_);

    function transferFrom(address owner_, address recipient_, uint256 amount_) external returns (bool success_);

}

// modules/withdrawal-manager-queue/modules/maple-proxy-factory/modules/proxy-factory/contracts/SlotManipulatable.sol

abstract contract SlotManipulatable {

    function _getReferenceTypeSlot(bytes32 slot_, bytes32 key_) internal pure returns (bytes32 value_) {
        return keccak256(abi.encodePacked(key_, slot_));
    }

    function _getSlotValue(bytes32 slot_) internal view returns (bytes32 value_) {
        assembly {
            value_ := sload(slot_)
        }
    }

    function _setSlotValue(bytes32 slot_, bytes32 value_) internal {
        assembly {
            sstore(slot_, value_)
        }
    }

}

// modules/withdrawal-manager-queue/modules/maple-proxy-factory/modules/proxy-factory/contracts/interfaces/IDefaultImplementationBeacon.sol

/// @title An beacon that provides a default implementation for proxies, must implement IDefaultImplementationBeacon.
interface IDefaultImplementationBeacon {

    /// @dev The address of an implementation for proxies.
    function defaultImplementation() external view returns (address defaultImplementation_);

}

// modules/withdrawal-manager-queue/modules/maple-proxy-factory/modules/proxy-factory/contracts/interfaces/IProxied.sol

/// @title An implementation that is to be proxied, must implement IProxied.
interface IProxied {

    /**
     *  @dev The address of the proxy factory.
     */
    function factory() external view returns (address factory_);

    /**
     *  @dev The address of the implementation contract being proxied.
     */
    function implementation() external view returns (address implementation_);

    /**
     *  @dev   Modifies the proxy's implementation address.
     *  @param newImplementation_ The address of an implementation contract.
     */
    function setImplementation(address newImplementation_) external;

    /**
     *  @dev   Modifies the proxy's storage by delegate-calling a migrator contract with some arguments.
     *         Access control logic critical since caller can force a selfdestruct via a malicious `migrator_` which is delegatecalled.
     *  @param migrator_  The address of a migrator contract.
     *  @param arguments_ Some encoded arguments to use for the migration.
     */
    function migrate(address migrator_, bytes calldata arguments_) external;

}

// modules/withdrawal-manager-queue/modules/erc20-helper/src/ERC20Helper.sol

/**
 * @title Small Library to standardize erc20 token interactions.
 */
library ERC20Helper {

    /**************************************************************************************************************************************/
    /*** Internal Functions                                                                                                             ***/
    /**************************************************************************************************************************************/

    function transfer(address token_, address to_, uint256 amount_) internal returns (bool success_) {
        return _call(token_, abi.encodeWithSelector(IERC20Like_1.transfer.selector, to_, amount_));
    }

    function transferFrom(address token_, address from_, address to_, uint256 amount_) internal returns (bool success_) {
        return _call(token_, abi.encodeWithSelector(IERC20Like_1.transferFrom.selector, from_, to_, amount_));
    }

    function approve(address token_, address spender_, uint256 amount_) internal returns (bool success_) {
        // If setting approval to zero fails, return false.
        if (!_call(token_, abi.encodeWithSelector(IERC20Like_1.approve.selector, spender_, uint256(0)))) return false;

        // If `amount_` is zero, return true as the previous step already did this.
        if (amount_ == uint256(0)) return true;

        // Return the result of setting the approval to `amount_`.
        return _call(token_, abi.encodeWithSelector(IERC20Like_1.approve.selector, spender_, amount_));
    }

    function _call(address token_, bytes memory data_) private returns (bool success_) {
        if (token_.code.length == uint256(0)) return false;

        bytes memory returnData;
        ( success_, returnData ) = token_.call(data_);

        return success_ && (returnData.length == uint256(0) || abi.decode(returnData, (bool)));
    }

}

// modules/withdrawal-manager-queue/modules/maple-proxy-factory/contracts/interfaces/IMapleProxied.sol

/// @title A Maple implementation that is to be proxied, must implement IMapleProxied.
interface IMapleProxied is IProxied {

    /**
     *  @dev   The instance was upgraded.
     *  @param toVersion_ The new version of the loan.
     *  @param arguments_ The upgrade arguments, if any.
     */
    event Upgraded(uint256 toVersion_, bytes arguments_);

    /**
     *  @dev   Upgrades a contract implementation to a specific version.
     *         Access control logic critical since caller can force a selfdestruct via a malicious `migrator_` which is delegatecalled.
     *  @param toVersion_ The version to upgrade to.
     *  @param arguments_ Some encoded arguments to use for the upgrade.
     */
    function upgrade(uint256 toVersion_, bytes calldata arguments_) external;

}

// modules/withdrawal-manager-queue/modules/maple-proxy-factory/contracts/interfaces/IMapleProxyFactory.sol

/// @title A Maple factory for Proxy contracts that proxy MapleProxied implementations.
interface IMapleProxyFactory is IDefaultImplementationBeacon {

    /**************************************************************************************************************************************/
    /*** Events                                                                                                                         ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev   A default version was set.
     *  @param version_ The default version.
     */
    event DefaultVersionSet(uint256 indexed version_);

    /**
     *  @dev   A version of an implementation, at some address, was registered, with an optional initializer.
     *  @param version_               The version registered.
     *  @param implementationAddress_ The address of the implementation.
     *  @param initializer_           The address of the initializer, if any.
     */
    event ImplementationRegistered(uint256 indexed version_, address indexed implementationAddress_, address indexed initializer_);

    /**
     *  @dev   A proxy contract was deployed with some initialization arguments.
     *  @param version_                 The version of the implementation being proxied by the deployed proxy contract.
     *  @param instance_                The address of the proxy contract deployed.
     *  @param initializationArguments_ The arguments used to initialize the proxy contract, if any.
     */
    event InstanceDeployed(uint256 indexed version_, address indexed instance_, bytes initializationArguments_);

    /**
     *  @dev   A instance has upgraded by proxying to a new implementation, with some migration arguments.
     *  @param instance_           The address of the proxy contract.
     *  @param fromVersion_        The initial implementation version being proxied.
     *  @param toVersion_          The new implementation version being proxied.
     *  @param migrationArguments_ The arguments used to migrate, if any.
     */
    event InstanceUpgraded(address indexed instance_, uint256 indexed fromVersion_, uint256 indexed toVersion_, bytes migrationArguments_);

    /**
     *  @dev   The MapleGlobals was set.
     *  @param mapleGlobals_ The address of a Maple Globals contract.
     */
    event MapleGlobalsSet(address indexed mapleGlobals_);

    /**
     *  @dev   An upgrade path was disabled, with an optional migrator contract.
     *  @param fromVersion_ The starting version of the upgrade path.
     *  @param toVersion_   The destination version of the upgrade path.
     */
    event UpgradePathDisabled(uint256 indexed fromVersion_, uint256 indexed toVersion_);

    /**
     *  @dev   An upgrade path was enabled, with an optional migrator contract.
     *  @param fromVersion_ The starting version of the upgrade path.
     *  @param toVersion_   The destination version of the upgrade path.
     *  @param migrator_    The address of the migrator, if any.
     */
    event UpgradePathEnabled(uint256 indexed fromVersion_, uint256 indexed toVersion_, address indexed migrator_);

    /**************************************************************************************************************************************/
    /*** State Variables                                                                                                                ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev The default version.
     */
    function defaultVersion() external view returns (uint256 defaultVersion_);

    /**
     *  @dev The address of the MapleGlobals contract.
     */
    function mapleGlobals() external view returns (address mapleGlobals_);

    /**
     *  @dev    Whether the upgrade is enabled for a path from a version to another version.
     *  @param  toVersion_   The initial version.
     *  @param  fromVersion_ The destination version.
     *  @return allowed_     Whether the upgrade is enabled.
     */
    function upgradeEnabledForPath(uint256 toVersion_, uint256 fromVersion_) external view returns (bool allowed_);

    /**************************************************************************************************************************************/
    /*** State Changing Functions                                                                                                       ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev    Deploys a new instance proxying the default implementation version, with some initialization arguments.
     *          Uses a nonce and `msg.sender` as a salt for the CREATE2 opcode during instantiation to produce deterministic addresses.
     *  @param  arguments_ The initialization arguments to use for the instance deployment, if any.
     *  @param  salt_      The salt to use in the contract creation process.
     *  @return instance_  The address of the deployed proxy contract.
     */
    function createInstance(bytes calldata arguments_, bytes32 salt_) external returns (address instance_);

    /**
     *  @dev   Enables upgrading from a version to a version of an implementation, with an optional migrator.
     *         Only the Governor can call this function.
     *  @param fromVersion_ The starting version of the upgrade path.
     *  @param toVersion_   The destination version of the upgrade path.
     *  @param migrator_    The address of the migrator, if any.
     */
    function enableUpgradePath(uint256 fromVersion_, uint256 toVersion_, address migrator_) external;

    /**
     *  @dev   Disables upgrading from a version to a version of a implementation.
     *         Only the Governor can call this function.
     *  @param fromVersion_ The starting version of the upgrade path.
     *  @param toVersion_   The destination version of the upgrade path.
     */
    function disableUpgradePath(uint256 fromVersion_, uint256 toVersion_) external;

    /**
     *  @dev   Registers the address of an implementation contract as a version, with an optional initializer.
     *         Only the Governor can call this function.
     *  @param version_               The version to register.
     *  @param implementationAddress_ The address of the implementation.
     *  @param initializer_           The address of the initializer, if any.
     */
    function registerImplementation(uint256 version_, address implementationAddress_, address initializer_) external;

    /**
     *  @dev   Sets the default version.
     *         Only the Governor can call this function.
     *  @param version_ The implementation version to set as the default.
     */
    function setDefaultVersion(uint256 version_) external;

    /**
     *  @dev   Sets the Maple Globals contract.
     *         Only the Governor can call this function.
     *  @param mapleGlobals_ The address of a Maple Globals contract.
     */
    function setGlobals(address mapleGlobals_) external;

    /**
     *  @dev   Upgrades the calling proxy contract's implementation, with some migration arguments.
     *  @param toVersion_ The implementation version to upgrade the proxy contract to.
     *  @param arguments_ The migration arguments, if any.
     */
    function upgradeInstance(uint256 toVersion_, bytes calldata arguments_) external;

    /**************************************************************************************************************************************/
    /*** View Functions                                                                                                                 ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev    Returns the deterministic address of a potential proxy, given some arguments and salt.
     *  @param  arguments_       The initialization arguments to be used when deploying the proxy.
     *  @param  salt_            The salt to be used when deploying the proxy.
     *  @return instanceAddress_ The deterministic address of a potential proxy.
     */
    function getInstanceAddress(bytes calldata arguments_, bytes32 salt_) external view returns (address instanceAddress_);

    /**
     *  @dev    Returns the address of an implementation version.
     *  @param  version_        The implementation version.
     *  @return implementation_ The address of the implementation.
     */
    function implementationOf(uint256 version_) external view returns (address implementation_);

    /**
     *  @dev    Returns if a given address has been deployed by this factory/
     *  @param  instance_   The address to check.
     *  @return isInstance_ A boolean indication if the address has been deployed by this factory.
     */
    function isInstance(address instance_) external view returns (bool isInstance_);

    /**
     *  @dev    Returns the address of a migrator contract for a migration path (from version, to version).
     *          If oldVersion_ == newVersion_, the migrator is an initializer.
     *  @param  oldVersion_ The old version.
     *  @param  newVersion_ The new version.
     *  @return migrator_   The address of a migrator contract.
     */
    function migratorForPath(uint256 oldVersion_, uint256 newVersion_) external view returns (address migrator_);

    /**
     *  @dev    Returns the version of an implementation contract.
     *  @param  implementation_ The address of an implementation contract.
     *  @return version_        The version of the implementation contract.
     */
    function versionOf(address implementation_) external view returns (uint256 version_);

}

// modules/withdrawal-manager-queue/modules/maple-proxy-factory/modules/proxy-factory/contracts/ProxiedInternals.sol

/// @title An implementation that is to be proxied, will need ProxiedInternals.
abstract contract ProxiedInternals is SlotManipulatable {

    /// @dev Storage slot with the address of the current factory. `keccak256('eip1967.proxy.factory') - 1`.
    bytes32 private constant FACTORY_SLOT = bytes32(0x7a45a402e4cb6e08ebc196f20f66d5d30e67285a2a8aa80503fa409e727a4af1);

    /// @dev Storage slot with the address of the current factory. `keccak256('eip1967.proxy.implementation') - 1`.
    bytes32 private constant IMPLEMENTATION_SLOT = bytes32(0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc);

    /// @dev Delegatecalls to a migrator contract to manipulate storage during an initialization or migration.
    function _migrate(address migrator_, bytes calldata arguments_) internal virtual returns (bool success_) {
        uint256 size;

        assembly {
            size := extcodesize(migrator_)
        }

        if (size == uint256(0)) return false;

        ( success_, ) = migrator_.delegatecall(arguments_);
    }

    /// @dev Sets the factory address in storage.
    function _setFactory(address factory_) internal virtual returns (bool success_) {
        _setSlotValue(FACTORY_SLOT, bytes32(uint256(uint160(factory_))));
        return true;
    }

    /// @dev Sets the implementation address in storage.
    function _setImplementation(address implementation_) internal virtual returns (bool success_) {
        _setSlotValue(IMPLEMENTATION_SLOT, bytes32(uint256(uint160(implementation_))));
        return true;
    }

    /// @dev Returns the factory address.
    function _factory() internal view virtual returns (address factory_) {
        return address(uint160(uint256(_getSlotValue(FACTORY_SLOT))));
    }

    /// @dev Returns the implementation address.
    function _implementation() internal view virtual returns (address implementation_) {
        return address(uint160(uint256(_getSlotValue(IMPLEMENTATION_SLOT))));
    }

}

// modules/withdrawal-manager-queue/contracts/proxy/MapleWithdrawalManagerStorage.sol

contract MapleWithdrawalManagerStorage is IMapleWithdrawalManagerStorage {

    /**************************************************************************************************************************************/
    /*** Structs                                                                                                                        ***/
    /**************************************************************************************************************************************/

    struct WithdrawalRequest {
        address owner;
        uint256 shares;
    }

    struct Queue {
        uint128 nextRequestId;  // Identifier of the next request that will be processed.
        uint128 lastRequestId;  // Identifier of the last created request.
        mapping(uint128 => WithdrawalRequest) requests;  // Maps withdrawal requests to their positions in the queue.
    }

    /**************************************************************************************************************************************/
    /*** State Variables                                                                                                                ***/
    /**************************************************************************************************************************************/

    uint256 internal _locked;  // Used when checking for reentrancy.

    address public override pool;
    address public override poolManager;

    uint256 public override totalShares;  // Total amount of shares pending redemption.

    Queue public override queue;

    mapping(address => bool) public override isManualWithdrawal;  // Defines which users use automated withdrawals (false by default).

    mapping(address => uint128) internal __deprecated_requestIds;  // Maps users to their last withdrawal request.

    mapping(address => uint256) public override manualSharesAvailable;  // Shares available to withdraw for a given manual owner.

    mapping(address => uint256) public override userEscrowedShares;  // Maps users to their escrowed shares yet to be processed.

    mapping(address => SortedLinkedList.List) internal _userRequests;  // Maps users to their withdrawal requests.

}

// modules/withdrawal-manager-queue/modules/maple-proxy-factory/contracts/MapleProxiedInternals.sol

/// @title A Maple implementation that is to be proxied, will need MapleProxiedInternals.
abstract contract MapleProxiedInternals is ProxiedInternals { }

// modules/withdrawal-manager-queue/contracts/interfaces/IMapleWithdrawalManager.sol

interface IMapleWithdrawalManager is IMapleWithdrawalManagerStorage, IMapleProxied {

    /**************************************************************************************************************************************/
    /*** Events                                                                                                                         ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev   Emitted when empty redemption requests are processed.
     *  @param numberOfRequestsProcessed Number of empty requests that were processed.
     */
    event EmptyRedemptionsProcessed(uint256 numberOfRequestsProcessed);

    /**
     *  @dev   Emitted when a manual redemption takes place.
     *  @param owner           Address of the account.
     *  @param sharesDecreased Amount of shares redeemed.
     */
    event ManualSharesDecreased(address indexed owner, uint256 sharesDecreased);

    /**
     *  @dev   Emitted when a manual redemption is processed.
     *  @param requestId   Identifier of the withdrawal request.
     *  @param owner       Address of the account.
     *  @param sharesAdded Amount of shares added to the redeemable amount.
     */
    event ManualSharesIncreased(uint256 indexed requestId, address indexed owner, uint256 sharesAdded);

    /**
     *  @dev   Emitted when the withdrawal type of an account is updated.
     *  @param owner     Address of the account.
     *  @param isManual `true` if the withdrawal is manual, `false` if it is automatic.
     */
    event ManualWithdrawalSet(address indexed owner, bool isManual);

    /**
     *  @dev   Emitted when a withdrawal request is created.
     *  @param requestId Identifier of the withdrawal request.
     *  @param owner     Address of the owner of the shares.
     *  @param shares    Amount of shares requested for redemption.
     */
    event RequestCreated(uint256 indexed requestId, address indexed owner, uint256 shares);

    /**
     *  @dev   Emitted when a withdrawal request is updated.
     *  @param requestId Identifier of the withdrawal request.
     *  @param shares    Amount of shares reduced during a redemption request.
     */
    event RequestDecreased(uint256 indexed requestId, uint256 shares);

    /**
     *  @dev   Emitted when a withdrawal request is processed.
     *  @param requestId Identifier of the withdrawal request.
     *  @param owner     The owner of the shares.
     *  @param shares    Amount of redeemable shares.
     *  @param assets    Amount of withdrawable assets.
     */
    event RequestProcessed(uint256 indexed requestId, address indexed owner, uint256 shares, uint256 assets);

    /**
     *  @dev   Emitted when a withdrawal request is removed.
     *  @param requestId Identifier of the withdrawal request.
     */
    event RequestRemoved(uint256 indexed requestId);

    /**************************************************************************************************************************************/
    /*** State-Changing Functions                                                                                                       ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev   Add shares to the withdrawal manager.
     *  @param shares Amount of shares to add.
     *  @param owner  Address of the owner of shares.
     */
    function addShares(uint256 shares, address owner) external returns (uint256 lastRequestId);

    /**
     *  @dev   Processes empty redemption requests at the front of the queue.
     *         Iterates through the queue starting from the front and advances the queue's nextRequestId
     *         for each empty request encountered. Stops when a non-empty request is found or the
     *         specified number of requests has been processed.
     *  @param numberOfRequests Maximum number of empty requests to process.
     */
    function processEmptyRedemptions(uint256 numberOfRequests) external;

    /**
     *  @dev    Processes a withdrawal request.
     *          Uses the current exchange rate to calculate the amount of assets withdrawn.
     *  @param  shares           Amount of shares that should be redeemed.
     *  @param  owner            Address of the account to process.
     *  @return redeemableShares Amount of shares that will be burned.
     *  @return resultingAssets  Amount of assets that will be withdrawn.
     */
    function processExit(uint256 shares, address owner) external returns (uint256 redeemableShares, uint256 resultingAssets);

    /**
     *  @dev   Processes pending redemption requests.
     *         Requests are processed in the order they were submitted.
     *         Automatic withdrawal requests will be fulfilled atomically.
     *  @param maxSharesToProcess Maximum number of shares that will be processed during the call.
     */
    function processRedemptions(uint256 maxSharesToProcess) external;

    /**
     *  @dev    Removes shares from the withdrawal manager.
     *  @param  shares         Amount of shares to remove.
     *  @param  owner          Address of the owner of shares.
     *  @return sharesReturned Amount of shares that were returned.
     */
    function removeShares(uint256 shares, address owner) external returns (uint256 sharesReturned);

    /**
     *  @dev    Remove shares from a specific withdrawal request.
     *  @param  requestId       Identifier of the withdrawal request that is being updated.
     *  @param  sharesToRemove  Amount of shares to remove from the request.
     *  @return sharesReturned  Amount of shares that were returned.
     *  @return sharesRemaining Amount of shares remaining in the request.
     */
    function removeSharesById(uint256 requestId, uint256 sharesToRemove) external returns (uint256 sharesReturned, uint256 sharesRemaining);

    /**
     *  @dev   Removes withdrawal requests from the queue.
     *         Can only be called by the pool delegate.
     *         NOTE: Not to be used in a router based system where the router is managing user requests.
     *  @param owner      Address of the owner of shares.
     *  @param requestIds Array of identifiers of the withdrawal requests to remove.
     */
    function removeRequest(address owner, uint256[] calldata requestIds) external;

    /**
     *  @dev   Defines if an account will withdraw shares manually or automatically.
     *  @param account  Address of the account.
     *  @param isManual `true` if the account withdraws manually, `false` if the withdrawals are performed automatically.
     */
    function setManualWithdrawal(address account, bool isManual) external;

    /**************************************************************************************************************************************/
    /*** View Functions                                                                                                                 ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev   Returns the address of the underlying pool asset.
     *  @param asset Address of the underlying pool asset.
     */
    function asset() external view returns (address asset);

    /**
     *  @dev   Returns the address of the globals contract.
     *  @param globals Address of the globals contract.
     */
    function globals() external view returns (address globals);

    /**
     *  @dev   Return the address of the governor.
     *  @param governor Address of the governor contract.
     */
    function governor() external view returns (address governor);

    /**
     *  @dev    Returns if a user is able to withdraw. Required for compatibility with pool managers.
     *          NOTE: Always returns true to fulfil interface requirements.
     *  @param  owner          The account to check if it's in withdraw window.
     *  @return isInExitWindow True if the account is in the withdraw window.
     */
    function isInExitWindow(address owner) external view returns (bool isInExitWindow);

    /**
     *  @dev    Gets the total amount of funds that need to be locked to fulfill exits.
     *          NOTE: Always zero for this implementation.
     *  @return lockedLiquidity The amount of locked liquidity.
     */
    function lockedLiquidity() external view returns (uint256 lockedLiquidity);

    /**
     *  @dev    Gets the amount of locked shares for an account.
     *  @param  owner        The address to check the exit for.
     *  @return lockedShares The amount of manual shares available.
     */
    function lockedShares(address owner) external view returns (uint256 lockedShares);

    /**
     *  @dev   Returns the address of the pool delegate.
     *  @param poolDelegate Address of the pool delegate.
     */
    function poolDelegate() external view returns (address poolDelegate);

    /**
     *  @dev    Returns the amount of shares that can be redeemed.
     *          NOTE: The `shares` value is ignored.
     *  @param  owner            Address of the share owner
     *  @param  shares           Amount of shares to redeem.
     *  @return redeemableShares Amount of shares that can be redeemed.
     *  @return resultingAssets  Amount of assets that can be withdrawn.
     */
    function previewRedeem(address owner, uint256 shares) external view returns (uint256 redeemableShares, uint256 resultingAssets);

    /**
     *  @dev    Gets the amount of shares that can be withdrawn.
     *          NOTE: Values just passed through as withdraw is not implemented.
     *  @param  owner            The address to check the withdrawal for.
     *  @param  assets           The amount of requested shares to withdraw.
     *  @return redeemableAssets The amount of assets that can be withdrawn.
     *  @return resultingShares  The amount of shares that will be burned.
     */
    function previewWithdraw(address owner, uint256 assets) external view returns (uint256 redeemableAssets, uint256 resultingShares);

    /**
     *  @dev    Returns the last request id for a given owner.
     *          Function must exist for backwards compatibility with the old implementation where we supported only one request per owner.
     *  @param  owner          The account to check the last request id for.
     *  @return requestId      The id of the last valid withdrawal request for the account.
     */
    function requestIds(address owner) external view returns (uint256 requestId);

    /**
     *  @dev    Returns the owner and amount of shares associated with a withdrawal request.
     *  @param  requestId Identifier of the withdrawal request.
     *  @return owner     Address of the share owner.
     *  @return shares    Amount of shares pending redemption.
     */
    function requests(uint256 requestId) external view returns (address owner, uint256 shares);

    /**
     *  @dev    Returns the pending requests by owner.
     *          NOTE: This function may run out of gas if there are too many requests. Use the overload with pagination.
     *  @param  owner Address of the account to check for pending requests.
     *  @return requestIds Array of request identifiers.
     *  @return shares     Array of shares associated with each request.
     */
    function requestsByOwner(address owner) external view returns (uint256[] memory requestIds, uint256[] memory shares);

    /**
     *  @dev   Returns the address of the security admin.
     *  @param securityAdmin Address of the security admin.
     */
    function securityAdmin() external view returns (address securityAdmin);

}

// modules/withdrawal-manager-queue/contracts/MapleWithdrawalManager.sol

/*

    ███╗   ███╗ █████╗ ██████╗ ██╗     ███████╗
    ████╗ ████║██╔══██╗██╔══██╗██║     ██╔════╝
    ██╔████╔██║███████║██████╔╝██║     █████╗
    ██║╚██╔╝██║██╔══██║██╔═══╝ ██║     ██╔══╝
    ██║ ╚═╝ ██║██║  ██║██║     ███████╗███████╗
    ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝     ╚══════╝╚══════╝

    ██╗    ██╗██╗████████╗██╗  ██╗██████╗ ██████╗  █████╗ ██╗    ██╗ █████╗ ██╗
    ██║    ██║██║╚══██╔══╝██║  ██║██╔══██╗██╔══██╗██╔══██╗██║    ██║██╔══██╗██║
    ██║ █╗ ██║██║   ██║   ███████║██║  ██║██████╔╝███████║██║ █╗ ██║███████║██║
    ██║███╗██║██║   ██║   ██╔══██║██║  ██║██╔══██╗██╔══██║██║███╗██║██╔══██║██║
    ╚███╔███╔╝██║   ██║   ██║  ██║██████╔╝██║  ██║██║  ██║╚███╔███╔╝██║  ██║███████╗
    ╚══╝╚══╝ ╚═╝   ╚═╝   ╚═╝  ╚═╝╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝ ╚══╝╚══╝ ╚═╝  ╚═╝╚══════╝

    ███╗   ███╗ █████╗ ███╗   ██╗ █████╗  ██████╗ ███████╗██████╗
    ████╗ ████║██╔══██╗████╗  ██║██╔══██╗██╔════╝ ██╔════╝██╔══██╗
    ██╔████╔██║███████║██╔██╗ ██║███████║██║  ███╗█████╗  ██████╔╝
    ██║╚██╔╝██║██╔══██║██║╚██╗██║██╔══██║██║   ██║██╔══╝  ██╔══██╗
    ██║ ╚═╝ ██║██║  ██║██║ ╚████║██║  ██║╚██████╔╝███████╗██║  ██║
    ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝  ╚═╝

    ██╗   ██╗██████╗  ██████╗  ██████╗
    ██║   ██║╚════██╗██╔═████╗██╔═████╗
    ██║   ██║ █████╔╝██║██╔██║██║██╔██║
    ╚██╗ ██╔╝██╔═══╝ ████╔╝██║████╔╝██║
    ╚████╔╝ ███████╗╚██████╔╝╚██████╔╝
    ╚═══╝  ╚══════╝ ╚═════╝  ╚═════╝

*/

contract MapleWithdrawalManager is IMapleWithdrawalManager, MapleWithdrawalManagerStorage , MapleProxiedInternals {

    /**************************************************************************************************************************************/
    /*** Modifiers                                                                                                                      ***/
    /**************************************************************************************************************************************/

    modifier nonReentrant() {
        require(_locked == 1, "WM:LOCKED");

        _locked = 2;

        _;

        _locked = 1;
    }

    modifier onlyPoolDelegateOrOperationalAdmin {
        address globals_ = globals();

        require(
            msg.sender == IPoolManagerLike(poolManager).poolDelegate() ||
            msg.sender == IGlobalsLike(globals_).operationalAdmin(),
            "WM:NOT_POOL_DELEG_OR_OPS_ADMIN"
        );

        _;
    }

    modifier onlyPoolManager {
        require(msg.sender == poolManager, "WM:NOT_PM");

        _;
    }

    modifier onlyRedeemer {
        address globals_ = globals();

        require(
            IGlobalsLike(globals_).isInstanceOf("WITHDRAWAL_REDEEMER", msg.sender) ||
            msg.sender == IPoolManagerLike(poolManager).poolDelegate() ||
            msg.sender == IGlobalsLike(globals_).operationalAdmin(),
            "WM:NOT_REDEEMER"
        );

        _;
    }

    modifier whenProtocolNotPaused() {
        require(!IGlobalsLike(globals()).isFunctionPaused(msg.sig), "WM:PAUSED");
        _;
    }

    /**************************************************************************************************************************************/
    /*** Proxy Functions                                                                                                                ***/
    /**************************************************************************************************************************************/

    function migrate(address migrator_, bytes calldata arguments_) external override whenProtocolNotPaused {
        require(msg.sender == _factory(),        "WM:M:NOT_FACTORY");
        require(_migrate(migrator_, arguments_), "WM:M:FAILED");
    }

    function setImplementation(address implementation_) external override whenProtocolNotPaused {
        require(msg.sender == _factory(), "WM:SI:NOT_FACTORY");
        _setImplementation(implementation_);
    }

    function upgrade(uint256 version_, bytes calldata arguments_) external override whenProtocolNotPaused {
        address poolDelegate_ = poolDelegate();

        require(msg.sender == poolDelegate_ || msg.sender == securityAdmin(), "WM:U:NOT_AUTHORIZED");

        IGlobalsLike mapleGlobals_ = IGlobalsLike(globals());

        if (msg.sender == poolDelegate_) {
            require(mapleGlobals_.isValidScheduledCall(msg.sender, address(this), "WM:UPGRADE", msg.data), "WM:U:INVALID_SCHED_CALL");

            mapleGlobals_.unscheduleCall(msg.sender, "WM:UPGRADE", msg.data);
        }

        IMapleProxyFactory(_factory()).upgradeInstance(version_, arguments_);
    }

    /**************************************************************************************************************************************/
    /*** State-Changing Functions - OnlyPoolManager                                                                                     ***/
    /**************************************************************************************************************************************/

    function addShares(uint256 shares_, address owner_) external override onlyPoolManager returns (uint256 lastRequestId_) {
        require(shares_ > 0, "WM:AS:ZERO_SHARES");

        lastRequestId_ = _addRequest(owner_, shares_);
    }

    function processExit(
        uint256 shares_,
        address owner_
    )
        external override onlyPoolManager returns (
            uint256 redeemableShares_,
            uint256 resultingAssets_
        )
    {
        ( redeemableShares_, resultingAssets_ ) = owner_ == address(this)
            ? _calculateRedemption(shares_)
            : _processManualExit(shares_, owner_);
    }

    function removeShares(uint256 shares_, address owner_) external override onlyPoolManager returns (uint256 sharesReturned_) {
        require(shares_ > 0, "WM:RS:ZERO_SHARES");

        uint256 totalEscrowedShares_ = userEscrowedShares[owner_];

        require(totalEscrowedShares_ >= shares_, "WM:RS:INSUFFICIENT_SHARES");

        while (sharesReturned_ < shares_) {
            uint256 requestId_                = SortedLinkedList.getLast(_userRequests[owner_]);
            WithdrawalRequest memory request_ = queue.requests[_toUint128(requestId_)];

            uint256 sharesToRemove_ = _min(shares_ - sharesReturned_, request_.shares);
            sharesReturned_        += _removeShares(requestId_, sharesToRemove_, owner_, request_.shares);
        }
    }

    /**************************************************************************************************************************************/
    /*** State-Changing Functions - OnlyRedeemer                                                                                        ***/
    /**************************************************************************************************************************************/

    function processEmptyRedemptions(uint256 numberOfRequests_) external override whenProtocolNotPaused onlyRedeemer {
        require(numberOfRequests_ > 0, "WM:PER:ZERO_REQUESTS");

        uint256 nextRequestId_     = queue.nextRequestId;
        uint256 lastRequestId_     = queue.lastRequestId;
        uint256 requestsProcessed_ = 0;

        // Iterate through the queue and process empty requests, if the owner is address(0).
        while (requestsProcessed_ < numberOfRequests_ && nextRequestId_ <= lastRequestId_) {
            address owner_ = queue.requests[_toUint128(nextRequestId_)].owner;

            if (owner_ != address(0)) {
                // Stop if we encounter a non-empty request.
                break;
            }

            ++nextRequestId_;
            ++requestsProcessed_;
        }

        // Update the queue's next request ID.
        queue.nextRequestId = _toUint128(nextRequestId_);

        emit EmptyRedemptionsProcessed(requestsProcessed_);
    }

    function processRedemptions(uint256 maxSharesToProcess_) external override whenProtocolNotPaused nonReentrant onlyRedeemer {
        require(maxSharesToProcess_ > 0, "WM:PR:ZERO_SHARES");

        ( uint256 redeemableShares_, ) = _calculateRedemption(maxSharesToProcess_);

        // Revert if there are insufficient assets to redeem all shares.
        require(maxSharesToProcess_ == redeemableShares_, "WM:PR:LOW_LIQUIDITY");

        uint256 nextRequestId_ = queue.nextRequestId;
        uint256 lastRequestId_ = queue.lastRequestId;

        // Iterate through the loop and process as many requests as possible.
        // Stop iterating when there are no more shares to process or if you have reached the end of the queue.
        while (maxSharesToProcess_ > 0 && nextRequestId_ <= lastRequestId_) {
            ( uint256 sharesProcessed_, bool isProcessed_ ) = _processRequest(nextRequestId_, maxSharesToProcess_);

            // If the request has not been processed keep it at the start of the queue.
            // This request will be next in line to be processed on the next call.
            if (!isProcessed_) break;

            maxSharesToProcess_ -= sharesProcessed_;

            ++nextRequestId_;
        }

        // Adjust the new start of the queue.
        queue.nextRequestId = _toUint128(nextRequestId_);
    }

    // NOTE: Not to be used in a router based system where the router is managing user requests.
    function removeRequest(
        address owner_,
        uint256[] calldata requestIds_
    )
        external override whenProtocolNotPaused onlyRedeemer
    {
        require(owner_ != address(0),   "WM:RR:ZERO_OWNER");
        require(requestIds_.length > 0, "WM:RR:ZERO_REQUESTS");

        uint256 sharesToRemove_;

        WithdrawalRequest memory withdrawalRequest_;

        for (uint256 i = 0; i < requestIds_.length; ++i) {
            withdrawalRequest_ = queue.requests[_toUint128(requestIds_[i])];

            require(withdrawalRequest_.shares > 0,      "WM:RR:NOT_IN_QUEUE");
            require(withdrawalRequest_.owner == owner_, "WM:RR:NOT_OWNER");

            _removeRequest(owner_, requestIds_[i]);

            sharesToRemove_ += withdrawalRequest_.shares;
        }

        require(ERC20Helper.transfer(pool, owner_, sharesToRemove_), "WM:RR:TRANSFER_FAIL");

        totalShares -= sharesToRemove_;
    }

    function setManualWithdrawal(
        address owner_,
        bool isManual_
    )
        external override whenProtocolNotPaused onlyPoolDelegateOrOperationalAdmin
    {
        isManualWithdrawal[owner_] = isManual_;

        emit ManualWithdrawalSet(owner_, isManual_);
    }

    /**************************************************************************************************************************************/
    /*** Unprivileged External Functions                                                                                                ***/
    /**************************************************************************************************************************************/

    function removeSharesById(
        uint256 requestId_,
        uint256 sharesToRemove_
    )
        external override whenProtocolNotPaused nonReentrant returns (uint256 sharesReturned_, uint256 sharesRemaining_)
    {
        WithdrawalRequest memory request_ = queue.requests[_toUint128(requestId_)];

        require(request_.owner != address(0),       "WM:RSBI:INVALID_REQUEST");
        require(request_.owner == msg.sender,       "WM:RSBI:NOT_OWNER");
        require(sharesToRemove_ != 0,               "WM:RSBI:NO_CHANGE");
        require(sharesToRemove_ <= request_.shares, "WM:RSBI:INSUFFICIENT_SHARES");

        // Removes shares and will cancel the request if there are no shares remaining.
        sharesReturned_  = _removeShares(requestId_, sharesToRemove_, request_.owner, request_.shares);
        sharesRemaining_ = request_.shares - sharesToRemove_;
    }

    /**************************************************************************************************************************************/
    /*** Internal Functions                                                                                                             ***/
    /**************************************************************************************************************************************/

    function _addRequest(address owner_, uint256 shares_) internal returns (uint256 lastRequestId_) {
        lastRequestId_ = ++queue.lastRequestId;

        queue.requests[_toUint128(lastRequestId_)] = WithdrawalRequest(owner_, shares_);
        userEscrowedShares[owner_]                += shares_;

        SortedLinkedList.push(_userRequests[owner_], _toUint128(lastRequestId_));

        // Increase the number of shares locked.
        totalShares += shares_;

        require(ERC20Helper.transferFrom(pool, msg.sender, address(this), shares_), "WM:AS:FAILED_TRANSFER");

        emit RequestCreated(lastRequestId_, owner_, shares_);
    }

    function _removeShares(
        uint256 requestId_,
        uint256 sharesToRemove_,
        address owner_,
        uint256 currentShares_
    )
        internal returns (uint256 sharesReturned_)
    {
        uint256 sharesRemaining_ = currentShares_ - sharesToRemove_;

        totalShares -= sharesToRemove_;

        // If there are no shares remaining, cancel the withdrawal request.
        if (sharesRemaining_ == 0) {
            _removeRequest(owner_, requestId_);
        } else {
            queue.requests[_toUint128(requestId_)].shares = sharesRemaining_;
            userEscrowedShares[owner_]                   -= sharesToRemove_;

            emit RequestDecreased(requestId_, sharesToRemove_);
        }

        require(ERC20Helper.transfer(pool, owner_, sharesToRemove_), "WM:RS:TRANSFER_FAIL");

        sharesReturned_ = sharesToRemove_;
    }

    function _calculateRedemption(uint256 sharesToRedeem_) internal view returns (uint256 redeemableShares_, uint256 resultingAssets_) {
        IPoolManagerLike poolManager_ = IPoolManagerLike(poolManager);

        uint256 totalSupply_           = IPoolLike(pool).totalSupply();
        uint256 totalAssetsWithLosses_ = poolManager_.totalAssets() - poolManager_.unrealizedLosses();
        uint256 availableLiquidity_    = IERC20Like_0(asset()).balanceOf(pool);
        uint256 requiredLiquidity_     = totalAssetsWithLosses_ * sharesToRedeem_ / totalSupply_;

        bool partialLiquidity_ = availableLiquidity_ < requiredLiquidity_;

        redeemableShares_ = partialLiquidity_ ? sharesToRedeem_ * availableLiquidity_ / requiredLiquidity_ : sharesToRedeem_;
        resultingAssets_  = totalAssetsWithLosses_ * redeemableShares_  / totalSupply_;
    }

    function _min(uint256 a_, uint256 b_) internal pure returns (uint256 min_) {
        min_ = a_ < b_ ? a_ : b_;
    }

    function _processManualExit(
        uint256 shares_,
        address owner_
    )
        internal returns (
            uint256 redeemableShares_,
            uint256 resultingAssets_
        )
    {
        require(shares_ > 0,                              "WM:PE:NO_SHARES");
        require(shares_ <= manualSharesAvailable[owner_], "WM:PE:TOO_MANY_SHARES");

        ( redeemableShares_ , resultingAssets_ ) = _calculateRedemption(shares_);

        require(shares_ == redeemableShares_, "WM:PE:NOT_ENOUGH_LIQUIDITY");

        manualSharesAvailable[owner_] -= redeemableShares_;

        emit ManualSharesDecreased(owner_, redeemableShares_);

        // Unlock the reserved shares.
        totalShares -= redeemableShares_;

        require(ERC20Helper.transfer(pool, owner_, redeemableShares_), "WM:PE:TRANSFER_FAIL");
    }

    function _processRequest(
        uint256 requestId_,
        uint256 maximumSharesToProcess_
    )
        internal returns (
            uint256 processedShares_,
            bool    isProcessed_
        )
    {
        WithdrawalRequest memory request_ = queue.requests[_toUint128(requestId_)];

        // If the request has already been cancelled, skip it.
        if (request_.owner == address(0)) return (0, true);

        // Process only up to the maximum amount of shares.
        uint256 sharesToProcess_ = _min(request_.shares, maximumSharesToProcess_);

        // Calculate how many shares can actually be redeemed.
        uint256 resultingAssets_;

        ( processedShares_, resultingAssets_ ) = _calculateRedemption(sharesToProcess_);

        uint256 sharesRemaining_ = request_.shares - processedShares_;

        // If there are no remaining shares, request has been fully processed.
        isProcessed_ = sharesRemaining_ == 0;

        emit RequestProcessed(requestId_, request_.owner, processedShares_, resultingAssets_);

        // If the request has been fully processed, remove it from the queue.
        if (isProcessed_) {
            _removeRequest(request_.owner, requestId_);
        } else {
            // Update the withdrawal request.
            queue.requests[_toUint128(requestId_)].shares = sharesRemaining_;
            userEscrowedShares[request_.owner]           -= processedShares_;

            emit RequestDecreased(requestId_, processedShares_);
        }

        // If the owner opts for manual redemption, increase the account's available shares.
        if (isManualWithdrawal[request_.owner]) {
            manualSharesAvailable[request_.owner] += processedShares_;

            emit ManualSharesIncreased(requestId_, request_.owner, processedShares_);
        } else {
            // Otherwise, just adjust totalShares and perform the redeem.
            totalShares -= processedShares_;

            IPoolLike(pool).redeem(processedShares_, request_.owner, address(this));
        }
    }

    function _removeRequest(address owner_, uint256 requestId_) internal {
        userEscrowedShares[owner_] -= queue.requests[_toUint128(requestId_)].shares;
        SortedLinkedList.remove(_userRequests[owner_], _toUint128(requestId_));
        delete queue.requests[_toUint128(requestId_)];

        emit RequestRemoved(requestId_);
    }

    function _toUint128(uint256 input_) internal pure returns (uint128 output_) {
        require(input_ <= uint256(type(uint128).max), "WM:TU:UINT256_CAST");
        output_ = uint128(input_);
    }

    /**************************************************************************************************************************************/
    /*** View Functions                                                                                                                 ***/
    /**************************************************************************************************************************************/

    function asset() public view override returns (address asset_) {
        asset_ = IPoolLike(pool).asset();
    }

    function factory() external view override returns (address factory_) {
        factory_ = _factory();
    }

    function globals() public view override returns (address globals_) {
        globals_ = IMapleProxyFactory(_factory()).mapleGlobals();
    }

    function governor() public view override returns (address governor_) {
        governor_ = IGlobalsLike(globals()).governor();
    }

    function implementation() external view override returns (address implementation_) {
        implementation_ = _implementation();
    }

    function isInExitWindow(address owner_) external pure override returns (bool isInExitWindow_) {
        owner_;  // Silence warning

        isInExitWindow_ = true;
    }

    function lockedLiquidity() external pure override returns (uint256 lockedLiquidity_) {
        // At the Pool Delegate's discretion whether to service withdrawals or fund loans.
        // NOTE: Always zero.
        return lockedLiquidity_;
    }

    function lockedShares(address owner_) external view override returns (uint256 lockedShares_) {
        // Used for maxRedeem and requires a redemption request to be processed.
        lockedShares_ = manualSharesAvailable[owner_];
    }

    function poolDelegate() public view override returns (address poolDelegate_) {
        poolDelegate_ = IPoolManagerLike(poolManager).poolDelegate();
    }

    function previewRedeem(
        address owner_,
        uint256 shares_
    )
        public view override returns (
            uint256 redeemableShares_,
            uint256 resultingAssets_
        )
    {
        uint256 sharesAvailable_ = manualSharesAvailable[owner_];

        if (sharesAvailable_ == 0) return ( 0, 0 );

        require(shares_ <= sharesAvailable_, "WM:PR:TOO_MANY_SHARES");

        ( redeemableShares_, resultingAssets_ ) = _calculateRedemption(shares_);  // NOTE: Recommend using convertToExitAssets instead
    }

    function previewWithdraw(address owner_, uint256 assets_)
        external pure override returns (uint256 redeemableAssets_, uint256 resultingShares_)
    {
        owner_; assets_; redeemableAssets_; resultingShares_;  // Silence compiler warnings
        return ( redeemableAssets_, resultingShares_ );  // NOTE: Withdrawal not implemented use redeem instead
    }

    function requestIds(address owner_) external view override returns (uint256 requestId_) {
        requestId_ = SortedLinkedList.getLast(_userRequests[owner_]);
    }

    function requests(uint256 requestId_) external view override returns (address owner_, uint256 shares_) {
        owner_  = queue.requests[_toUint128(requestId_)].owner;
        shares_ = queue.requests[_toUint128(requestId_)].shares;
    }

    function requestsByOwner(address owner_) external view override returns (uint256[] memory requestIds_, uint256[] memory shares_) {
        uint128[] memory requestIdsByOwner_ = SortedLinkedList.getAllValues(_userRequests[owner_]);

        requestIds_ = new uint256[](requestIdsByOwner_.length);
        shares_     = new uint256[](requestIdsByOwner_.length);

        for (uint256 i = 0; i < requestIdsByOwner_.length; ++i) {
            requestIds_[i] = requestIdsByOwner_[i];
            shares_[i]     = queue.requests[requestIdsByOwner_[i]].shares;
        }
    }

    function securityAdmin() public view override returns (address securityAdmin_) {
        securityAdmin_ = IGlobalsLike(globals()).securityAdmin();
    }

}