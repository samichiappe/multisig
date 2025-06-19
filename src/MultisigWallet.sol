// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title MultisigWallet
 * @author Your Name
 * @notice A multi-signature wallet contract that requires multiple confirmations for transactions
 * @dev This contract allows multiple owners to manage funds with configurable confirmation requirements
 */
contract MultisigWallet {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Emitted when a new transaction is submitted
    /// @param owner The address that submitted the transaction
    /// @param txIndex The index of the submitted transaction
    /// @param to The destination address of the transaction
    /// @param value The amount of Ether to send
    /// @param data The data payload of the transaction
    event SubmitTransaction(
        address indexed owner,
        uint indexed txIndex,
        address indexed to,
        uint value,
        bytes data
    );
    
    /// @notice Emitted when a transaction is confirmed by an owner
    /// @param owner The address that confirmed the transaction
    /// @param txIndex The index of the confirmed transaction
    event ConfirmTransaction(address indexed owner, uint indexed txIndex);
    
    /// @notice Emitted when a confirmation is revoked by an owner
    /// @param owner The address that revoked the confirmation
    /// @param txIndex The index of the transaction
    event RevokeConfirmation(address indexed owner, uint indexed txIndex);
    
    /// @notice Emitted when a transaction is executed
    /// @param owner The address that executed the transaction
    /// @param txIndex The index of the executed transaction
    event ExecuteTransaction(address indexed owner, uint indexed txIndex);
    
    /// @notice Emitted when a new owner is added
    /// @param owner The address of the new owner
    event AddOwner(address indexed owner);
    
    /// @notice Emitted when an owner is removed
    /// @param owner The address of the removed owner
    event RemoveOwner(address indexed owner);
    
    /// @notice Emitted when the confirmation requirement is changed
    /// @param numConfirmationsRequired The new number of confirmations required
    event ChangeRequirement(uint numConfirmationsRequired);
    
    /// @notice Emitted when Ether is deposited into the wallet
    /// @param sender The address that sent the Ether
    /// @param amount The amount of Ether deposited
    /// @param balance The new balance of the wallet
    event Deposit(address indexed sender, uint amount, uint balance);

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Structure representing a transaction
    /// @param to The destination address
    /// @param value The amount of Ether to send
    /// @param data The data payload
    /// @param executed Whether the transaction has been executed
    /// @param numConfirmations The number of confirmations received
    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
        uint numConfirmations;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Array of owner addresses
    address[] public owners;
    
    /// @notice Mapping to check if an address is an owner
    mapping(address => bool) public isOwner;
    
    /// @notice Number of confirmations required to execute a transaction
    uint public numConfirmationsRequired;
    
    /// @notice Array of all transactions
    Transaction[] public transactions;
    
    /// @notice Mapping from tx index => owner => bool (confirmation status)
    mapping(uint => mapping(address => bool)) public isConfirmed;
    
    /// @notice Minimum number of owners required
    uint public constant MIN_OWNERS = 3;
    
    /// @notice Minimum number of confirmations required
    uint public constant MIN_CONFIRMATIONS = 2;

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Ensures only owners can call the function
    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }
    
    /// @notice Ensures the transaction exists
    /// @param _txIndex The transaction index to check
    modifier txExists(uint _txIndex) {
        require(_txIndex < transactions.length, "tx does not exist");
        _;
    }
    
    /// @notice Ensures the transaction is not executed
    /// @param _txIndex The transaction index to check
    modifier notExecuted(uint _txIndex) {
        require(!transactions[_txIndex].executed, "tx already executed");
        _;
    }
    
    /// @notice Ensures the transaction is not confirmed by the caller
    /// @param _txIndex The transaction index to check
    modifier notConfirmed(uint _txIndex) {
        require(!isConfirmed[_txIndex][msg.sender], "tx already confirmed");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice Initializes the multisig wallet with owners and confirmation requirement
     * @param _owners Array of owner addresses
     * @param _numConfirmationsRequired Number of confirmations required for execution
     */
    constructor(address[] memory _owners, uint _numConfirmationsRequired) {
        require(_owners.length >= MIN_OWNERS, "owners required");
        require(
            _numConfirmationsRequired >= MIN_CONFIRMATIONS &&
                _numConfirmationsRequired <= _owners.length,
            "invalid number of required confirmations"
        );

        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];

            require(owner != address(0), "invalid owner");
            require(!isOwner[owner], "owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }

        numConfirmationsRequired = _numConfirmationsRequired;
    }

    /*//////////////////////////////////////////////////////////////
                           RECEIVE FUNCTION
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Allows the contract to receive Ether
    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    /*//////////////////////////////////////////////////////////////
                        TRANSACTION FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice Submits a new transaction for confirmation
     * @param _to The destination address
     * @param _value The amount of Ether to send
     * @param _data The data payload
     */
    function submitTransaction(
        address _to,
        uint _value,
        bytes memory _data
    ) public onlyOwner {
        uint txIndex = transactions.length;

        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                data: _data,
                executed: false,
                numConfirmations: 0
            })
        );

        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }

    /**
     * @notice Confirms a transaction
     * @param _txIndex The index of the transaction to confirm
     */
    function confirmTransaction(uint _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
        notConfirmed(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        transaction.numConfirmations += 1;
        isConfirmed[_txIndex][msg.sender] = true;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    /**
     * @notice Executes a confirmed transaction
     * @param _txIndex The index of the transaction to execute
     */
    function executeTransaction(uint _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];

        require(
            transaction.numConfirmations >= numConfirmationsRequired,
            "cannot execute tx"
        );

        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(success, "tx failed");

        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    /**
     * @notice Revokes confirmation for a transaction
     * @param _txIndex The index of the transaction
     */
    function revokeConfirmation(uint _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];

        require(isConfirmed[_txIndex][msg.sender], "tx not confirmed");

        transaction.numConfirmations -= 1;
        isConfirmed[_txIndex][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    /*//////////////////////////////////////////////////////////////
                          OWNER MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice Adds a new owner (requires multisig confirmation)
     * @param _owner The address of the new owner
     */
    function addOwner(address _owner) public {
        require(msg.sender == address(this), "only wallet can add owner");
        require(_owner != address(0), "invalid owner");
        require(!isOwner[_owner], "owner already exists");

        isOwner[_owner] = true;
        owners.push(_owner);

        emit AddOwner(_owner);
    }

    /**
     * @notice Removes an owner (requires multisig confirmation)
     * @param _owner The address of the owner to remove
     */
    function removeOwner(address _owner) public {
        require(msg.sender == address(this), "only wallet can remove owner");
        require(isOwner[_owner], "not an owner");
        require(owners.length > MIN_OWNERS, "cannot remove owner");

        isOwner[_owner] = false;

        for (uint i = 0; i < owners.length; i++) {
            if (owners[i] == _owner) {
                owners[i] = owners[owners.length - 1];
                owners.pop();
                break;
            }
        }

        // Adjust confirmation requirement if necessary
        if (numConfirmationsRequired > owners.length) {
            numConfirmationsRequired = owners.length;
            emit ChangeRequirement(numConfirmationsRequired);
        }

        emit RemoveOwner(_owner);
    }

    /**
     * @notice Changes the confirmation requirement (requires multisig confirmation)
     * @param _numConfirmationsRequired The new confirmation requirement
     */
    function changeRequirement(uint _numConfirmationsRequired) public {
        require(msg.sender == address(this), "only wallet can change requirement");
        require(
            _numConfirmationsRequired >= MIN_CONFIRMATIONS &&
                _numConfirmationsRequired <= owners.length,
            "invalid requirement"
        );

        numConfirmationsRequired = _numConfirmationsRequired;
        emit ChangeRequirement(_numConfirmationsRequired);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice Returns the list of owners
     * @return Array of owner addresses
     */
    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    /**
     * @notice Returns the number of transactions
     * @return The total number of transactions
     */
    function getTransactionCount() public view returns (uint) {
        return transactions.length;
    }

    /**
     * @notice Returns transaction details
     * @param _txIndex The transaction index
     * @return to The destination address
     * @return value The amount of Ether
     * @return data The data payload
     * @return executed Whether the transaction is executed
     * @return numConfirmations The number of confirmations
     */
    function getTransaction(uint _txIndex)
        public
        view
        returns (
            address to,
            uint value,
            bytes memory data,
            bool executed,
            uint numConfirmations
        )
    {
        Transaction storage transaction = transactions[_txIndex];

        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.numConfirmations
        );
    }
}
