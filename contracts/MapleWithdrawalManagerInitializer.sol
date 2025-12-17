// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.7 ^0.8.7;

// modules/withdrawal-manager-queue/contracts/interfaces/IMapleWithdrawalManagerInitializer.sol

interface IMapleWithdrawalManagerInitializer {

    /**
     *  @dev               Emitted when the withdrawal manager proxy contract is initialized.
     *  @param pool        Address of the pool contract.
     *  @param poolManager Address of the pool manager contract.
     */
    event Initialized(address indexed pool, address indexed poolManager);

}

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

interface IERC20Like {

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

// modules/withdrawal-manager-queue/modules/maple-proxy-factory/contracts/MapleProxiedInternals.sol

/// @title A Maple implementation that is to be proxied, will need MapleProxiedInternals.
abstract contract MapleProxiedInternals is ProxiedInternals { }

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

// modules/withdrawal-manager-queue/contracts/proxy/MapleWithdrawalManagerInitializer.sol

contract MapleWithdrawalManagerInitializer is IMapleWithdrawalManagerInitializer, MapleWithdrawalManagerStorage, MapleProxiedInternals {

    fallback() external {
        ( address pool_ ) = abi.decode(msg.data, (address));

        _initialize(pool_);
    }

    function _initialize(address pool_) internal {
        require(pool_ != address(0), "WMI:ZERO_POOL");

        address globals_     = IMapleProxyFactoryLike(msg.sender).mapleGlobals();
        address poolManager_ = IPoolLike(pool_).manager();
        address factory_     = IPoolManagerLike(poolManager_).factory();

        require(IGlobalsLike(globals_).isInstanceOf("POOL_MANAGER_FACTORY", factory_), "WMI:I:INVALID_PM_FACTORY");
        require(IMapleProxyFactoryLike(factory_).isInstance(poolManager_),             "WMI:I:INVALID_PM");

        _locked = 1;

        pool        = pool_;
        poolManager = poolManager_;

        queue.nextRequestId = 1;  // Initialize queue with index 1

        emit Initialized(pool_, poolManager_);
    }

}