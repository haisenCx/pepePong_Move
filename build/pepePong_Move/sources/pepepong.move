module pong_addr::pepepong {

	//////////////////
	//// Errors	   ///
	//////////////////
	///Roles Errors
	const ERR_REQUIRE_ADMIN_ROLE: u64 = 1;
	const ERR_REQUIRE_MINTER_ROLE: u64 = 2;
	const ERR_REQUIRE_NO_ROLE: u64 = 3;
	const ERR_ROLE_ALREADY_GRANTED: u64 = 4;
	///Token Errors
    const THE_ACCOUNT_HAS_BEEN_REGISTERED : u64 = 1;
    const INVALID_TOKEN_OWNER : u64 = 2;
    const THE_ACCOUNT_IS_NOT_REGISTERED : u64 = 3;
    const INSUFFICIENT_BALANCE : u64 = 4;
    const ECOIN_INFO_ALREADY_PUBLISHED : u64 = 5;
    const EXCEEDING_THE_TOTAL_SUPPLY : u64 = 6;
	const MAX_MINTS_REACHED : u64 = 7;
	const MINT_GAP_NOT_REACHED : u64 = 8;

	//////////////////
	//// use	   ///
	//////////////////
	use std::signer;
    use std::string;
	use std::account;
	use std::aptos_account;
    use std::event;
	use std::bcs;
    use std::hash;
	use std::coin::{Self, BurnCapability, MintCapability};
    use std::aptos_coin::{Self,AptosCoin};
    use std::timestamp; 
	use std::block;
	use std::create_signer;

	//////////////////
	//// Constants ///
	//////////////////
	//Roles
    const ADMIN_ROLE: u64 = 1;
    const MINTER_ROLE: u64 = 2;
	const NO_ROLE: u64 = 3;

    const MODULE_OWNER: address = @pong_addr;
	const MINT_GAP: u64 = 30; // 30 blocks, or approximately 60 seconds
    const MIGRATION_GAP: u64 = 30; // 30 blocks, or approximately 60 seconds
    const MAX_MINTS: u64 = 500_000; // 500,000 mints
    const INIT_AMOUNT: u64 = 1_000; // 1000 Pong, assuming Pong is a basic unit
    const MID_AMOUNT: u64 = 5_000; // 5,000 Pong
    const FINAL_AMOUNT: u64 = 10_000; // 10,000 Pong
    const EARLY_BIRD_FEE: u64 = 1; // Assuming 1 represents 0.001 ether equivalent in Pong
    const EARLY_BIRD_EPOCH: u64 = 4; // 4 epochs
    const INIT_FEE: u64 = 6; // Assuming 6 represents 0.006 ether equivalent in Pong
    const FEE_GAP: u64 = 2500; // Fee increases every 2500 mints
    const FEE_RATE: u64 = 8; // 0.8% fee increase
    const FEE_RATE_DENOMINATOR: u64 = 1000; // 1000

	//////////////////
	//// Events	   ///
	//////////////////
	#[event]
 	struct InitialTokenMintedEvent has drop, store {
        mint_id: vector<u8>,
        account: address,
        amount: u64,
        solana_address: vector<u8>,
        timestamp: u64,
    }
	#[event]
    struct MidTokenMintedEvent has drop, store {
        mint_id: vector<u8>,
        account: address,
        amount: u64,
        solana_address: vector<u8>,
        timestamp: u64,
    }
	#[event]
    struct FinalTokenMintedEvent has drop, store {
        mint_id: vector<u8>,
        account: address,
        amount: u64,
        solana_address: vector<u8>,
        timestamp: u64,
    }
	#[event]
    struct TokenMigrationStartedEvent has drop, store {
        mint_id: vector<u8>,
        amount: u64,
        solana_address: vector<u8>,
        timestamp: u64,
    }


    struct PongCoin has store {
        value : u64,
    }

	struct  PongCoinCap has key {
		burn_cap: BurnCapability<PongCoin>,
		mint_cap: MintCapability<PongCoin>,
	}

    struct PongCoinStore has key {
        pongCoin : PongCoin,
		role_id : u64,
		last_minted_block : u64,
    }

    struct PongCoinInfo has key {
		// current fee for minting
		currFee: u64,
		// total mints so far
		total_mints: u64,

    }

	/// The roleId contains the role id for the account. This is only moved
    /// to an account as a top-level resource, and is otherwise immovable.

    // =============
	// Role Granting
    fun  grant_role(admin: &signer,account_addr: address,_role_id: u64) acquires PongCoinStore {
		assert!(signer::address_of(admin) == MODULE_OWNER, INVALID_TOKEN_OWNER);

        //assert!(!exists<RoleId>(signer::address_of(account)), ERR_ROLE_ALREADY_GRANTED);
        let role_id = &mut borrow_global_mut<PongCoinStore>(account_addr).role_id;
		*role_id = _role_id;
    }
    public entry fun grant_minter_role(admin: &signer,_minter_addr: address) acquires PongCoinStore {
		grant_role(admin,_minter_addr, MINTER_ROLE);
    }
    // =============
    // Role Checking
    fun has_role(account: address, _role_id: u64): bool acquires PongCoinStore {
       exists<PongCoinStore>(account)
           && borrow_global<PongCoinStore>(account).role_id == _role_id
    }

    public fun getBalance(owner: address) : u64 acquires PongCoinStore{

        assert!(is_account_registered(owner), THE_ACCOUNT_IS_NOT_REGISTERED);
        borrow_global<PongCoinStore>(owner).pongCoin.value
    }


    public fun is_account_registered(account_addr : address) : bool{
        exists<PongCoinStore>(account_addr)
    }

	public entry fun register(msgsender : &signer) {
        let msgsender_addr = signer::address_of(msgsender);

        assert!(!exists<PongCoinStore>(msgsender_addr), THE_ACCOUNT_HAS_BEEN_REGISTERED);
        move_to(msgsender, PongCoinStore{ pongCoin : PongCoin{ value : 0 }, role_id : NO_ROLE, last_minted_block: 0});
		coin::register<PongCoin>(msgsender);
    }

	fun register_admin(msgsender : &signer) {
        let msgsender_addr = signer::address_of(msgsender);

        assert!(!exists<PongCoinStore>(msgsender_addr), THE_ACCOUNT_HAS_BEEN_REGISTERED);
        move_to(msgsender, PongCoinStore{ pongCoin : PongCoin{ value : 0 }, role_id : ADMIN_ROLE, last_minted_block: 0});
		coin::register<PongCoin>(msgsender);
    }


    public entry fun initialize(msg_sender : &signer) acquires PongCoinStore {
		assert!(signer::address_of(msg_sender) == MODULE_OWNER, INVALID_TOKEN_OWNER);

        assert!(!exists<PongCoinInfo>(MODULE_OWNER), ECOIN_INFO_ALREADY_PUBLISHED);

		init_coin(msg_sender);
        move_to(msg_sender, PongCoinInfo{currFee: INIT_FEE, total_mints: 0});

		register_admin(msg_sender);
		grant_role(msg_sender,signer::address_of(msg_sender), ADMIN_ROLE);

    }

	fun init_coin(sender: &signer) {

		let (burn_cap, freeze_cap, mint_cap) = coin::initialize<PongCoin>(
			sender,
				string::utf8(b"PepePong"),
				string::utf8(b"Pong"),
				18,
				true,
        );

        move_to(sender, PongCoinCap{
            burn_cap,
            mint_cap,
        });

		coin::destroy_freeze_cap<PongCoin>(freeze_cap);
    }
	
	// public entry fun initialize(msg_sender : &signer, _coordinator : address , _decimals : u64, _supply : u64) acquires PongCoinStore {
	// 	coin::initialize<PongCoin>(msgsender, MODULE_OWNER, aptos_currFee);

	// 	assert!(signer::address_of(msg_sender) == MODULE_OWNER, INVALID_TOKEN_OWNER);

    //     assert!(!exists<PongCoinInfo>(MODULE_OWNER), ECOIN_INFO_ALREADY_PUBLISHED);

    //     move_to(msg_sender, PongCoinInfo{name : string::utf8(b"Pepe Pong"), symbol : string::utf8(b"Pong"), decimals : _decimals, supply : _supply, cap : 0, currFee: INIT_FEE, total_mints: 0});

	// 	grant_role(msg_sender,signer::address_of(msg_sender), ADMIN_ROLE);
	// 	grant_role(msg_sender,_coordinator, MINTER_ROLE);

    // }

    public entry fun burn(owner : &signer, amount : u64) acquires PongCoinCap {

        assert!(signer::address_of(owner) == MODULE_OWNER, INVALID_TOKEN_OWNER);
		let cap = borrow_global<PongCoinCap>(MODULE_OWNER);
		let to_burn = coin::withdraw<PongCoin>(owner, amount);
		coin::burn(to_burn, &cap.burn_cap);
    }

	//mint for the invoking account
   	public entry fun mint(msgsender : &signer,aptos_currFee : u64, _solana_address: vector<u8>) acquires PongCoinStore,PongCoinInfo,PongCoinCap{
		//only noRole can mint
		//check:
		///1.only noRole can mint
		///2. if (totalMints > EARLY_BIRD_EPOCH * FEE_GAP) {
        //  	    require(msg.value >= currFee, "Insufficient msg.value");
        // 		}else {
        //     		require(msg.value >= EARLY_BIRD_FEE, "Insufficient msg.value");
        // 		}
		///3.require(totalMints < MAX_MINTS, "Max mints reached"); 
		///4.require(lastMintedBlock[msg.sender] + MINT_GAP < block.number,"Mint gap not reached");
		let msgsender_addr = signer::address_of(msgsender);
		assert!((!has_role(msgsender_addr, ADMIN_ROLE) && !has_role(msgsender_addr, MINTER_ROLE)), ERR_REQUIRE_NO_ROLE);
        let pong_coin_info_ref = borrow_global_mut<PongCoinInfo>(MODULE_OWNER);
        let total_mints = &mut pong_coin_info_ref.total_mints;
        let currFee = &mut pong_coin_info_ref.currFee;
		if (*total_mints > EARLY_BIRD_EPOCH * FEE_GAP) {
			assert!(aptos_currFee >= *currFee, INSUFFICIENT_BALANCE);
		}else {
			assert!(aptos_currFee >= EARLY_BIRD_FEE, INSUFFICIENT_BALANCE);
		};

		if(coin::is_account_registered<PongCoin>(msgsender_addr)){
			coin::register<PongCoin>(msgsender);
		};

		coin::transfer<AptosCoin>(msgsender, MODULE_OWNER, aptos_currFee);
		let _last_minted_block = &mut borrow_global_mut<PongCoinStore>(msgsender_addr).last_minted_block;
		let current_block_height = block::get_current_block_height();
        std::debug::print(&current_block_height);

		assert!(*total_mints < MAX_MINTS, MAX_MINTS_REACHED );
		//assert!(*_last_minted_block + MINT_GAP < current_block_height, MINT_GAP_NOT_REACHED);
		let mint_id  = 1;
		let bytes = bcs::to_bytes(&mint_id);
        let mint_id_encode = hash::sha2_256(bytes);
		
		let signer_address = signer::address_of(msgsender);
		*total_mints = *total_mints +1;
		if (*total_mints % FEE_GAP == 0) {
            *currFee =  *currFee + ((*currFee * FEE_RATE) / FEE_RATE_DENOMINATOR);
        };
		let cap = borrow_global<PongCoinCap>(MODULE_OWNER);
		let coin_mint = coin::mint(INIT_AMOUNT,&cap.mint_cap );
		coin::deposit<PongCoin>(msgsender_addr, coin_mint);
		*_last_minted_block=current_block_height;
		//last_minted_block = block_height;
        //deposit(msgsender_addr, PongCoin { value : INIT_AMOUNT });

		event::emit(InitialTokenMintedEvent{ 
			mint_id: mint_id_encode,
			account: @pong_addr,
			amount: INIT_AMOUNT,
			solana_address: _solana_address,
			timestamp:  timestamp::now_microseconds(),
    		}
		);

     }

   	public entry fun mid_mint(msgsender : &signer,to : address,_mint_id:vector<u8>,_solana_address:vector<u8>) acquires PongCoinStore,PongCoinCap{
		assert!(has_role( signer::address_of(msgsender), MINTER_ROLE), ERR_REQUIRE_MINTER_ROLE);
		let msgsender_addr = signer::address_of(msgsender);
		let cap = borrow_global<PongCoinCap>(MODULE_OWNER);
		let coin_mint = coin::mint(MID_AMOUNT,&cap.mint_cap );
		coin::deposit<PongCoin>(to, coin_mint);

   		event::emit(MidTokenMintedEvent{
			mint_id:_mint_id,
			account: @pong_addr,
			amount: MID_AMOUNT,
			solana_address: _solana_address,
			timestamp:  timestamp::now_microseconds(),
    	});
    }

	public entry fun final_mint(msgsender : &signer,to : address,_mint_id:vector<u8>, _solana_address:vector<u8>) acquires PongCoinStore,PongCoinCap{
		assert!(has_role( signer::address_of(msgsender), MINTER_ROLE), ERR_REQUIRE_MINTER_ROLE);
		let msgsender_addr = signer::address_of(msgsender);
		let cap = borrow_global<PongCoinCap>(MODULE_OWNER);
		let coin_mint = coin::mint(FINAL_AMOUNT,&cap.mint_cap );
		coin::deposit<PongCoin>(to, coin_mint);
   		event::emit(FinalTokenMintedEvent{
			mint_id:_mint_id,
			account: @pong_addr,
			amount: FINAL_AMOUNT,
			solana_address: _solana_address,
			timestamp:  timestamp::now_microseconds(),
		});
	}


    fun withdrawAPT(account_addr : address, amount : u64) : PongCoin acquires PongCoinStore {
        assert!(is_account_registered(account_addr), THE_ACCOUNT_IS_NOT_REGISTERED);
        let balance = getBalance(account_addr);
        assert!(balance >= amount, INSUFFICIENT_BALANCE);
        let balance_ref = &mut borrow_global_mut<PongCoinStore>(account_addr).pongCoin.value;
        *balance_ref = balance - amount;
        PongCoin { value: amount }
    }
	
	///////////////////
	//// Test Cases ///
	///////////////////
	#[test(admin = @pong_addr,coordinator = @0x111)]
	public entry fun test_initialize(admin: &signer,coordinator:&signer ) acquires PongCoinStore {

		//just make admin be the coordinator, for testing, in real world, 
		//they can be different accounts, and coordinator should register first
		let adminaddr = signer::address_of(admin);
		let coordinator_addr = signer::address_of(coordinator);
		account::create_account_if_does_not_exist(adminaddr);
		account::create_account_if_does_not_exist(coordinator_addr);
		initialize(admin);
		register(coordinator);
		grant_minter_role(admin,coordinator_addr);

	}

	
	#[test(admin = @pong_addr,coordinator = @0x111)]
	public entry fun test_grant_role(admin: &signer,coordinator:&signer) acquires PongCoinStore {
		test_initialize(admin,coordinator);

		let noRole = @0x456;
		// grant admin role
		grant_role(admin,signer::address_of(admin), ADMIN_ROLE);
		//grant_role(admin,minter, MINTER_ROLE);

		//check if admin has the role
		assert!(has_role(signer::address_of(admin),ADMIN_ROLE), ERR_REQUIRE_ADMIN_ROLE);
		//check if minter has the role
		//assert!(has_role(minter, MINTER_ROLE), ERR_REQUIRE_MINTER_ROLE);
		//assert!((!has_role(noRole, ADMIN_ROLE) && !has_role(noRole, MINTER_ROLE)), ERR_REQUIRE_NO_ROLE);

	}

	#[test(admin = @pong_addr,coordinator = @0x111,noRole = @0x456,aptos_framework = @0x1)]
	public entry fun test_mint(admin: &signer, noRole:&signer,aptos_framework: &signer,coordinator:&signer ) acquires PongCoinStore,PongCoinInfo,PongCoinCap {
		// set up global time for testing purpose
		//account::create_account_if_does_not_exist(signer::address_of(noRole));
		
        timestamp::set_time_has_started_for_testing(aptos_framework); 
        let admin_addr = signer::address_of(admin);
        let (burn_cap, mint_cap) = aptos_framework::aptos_coin::initialize_for_test(aptos_framework);
        let noRole_addr = signer::address_of(noRole);
        account::create_account_for_test(noRole_addr);
		account::create_account_for_test(admin_addr);

        coin::register<AptosCoin>(noRole);
		coin::register<AptosCoin>(admin);

		aptos_coin::mint(aptos_framework, @0x456, 3000000000000);
		std::debug::print(&coin::balance<AptosCoin>(signer::address_of(noRole)));

   		//just make admin be the coordinator, for testing, in real world, 
		//they can be different accounts, and coordinator should register first
		test_initialize(admin,coordinator);
		register(noRole);
		assert!(coin::balance<PongCoin>(signer::address_of(noRole)) == 0, 2);
		mint(noRole, 100,b"abc");
		std::debug::print(&coin::balance<PongCoin>(signer::address_of(noRole)));
		assert!(coin::balance<PongCoin>(signer::address_of(noRole)) == INIT_AMOUNT, 2);

		coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
	}

	
	

}