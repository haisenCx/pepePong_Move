module pong_addr::i_pepepong {
    struct InitialTokenMintedEvent has drop, store {
        mint_id: vector<u8>,
        account: address,
        amount: u128,
        solana_address: vector<u8>,
        timestamp: u64,
    }

    struct MidTokenMintedEvent has drop, store {
        mint_id: vector<u8>,
        account: address,
        amount: u128,
        solana_address: vector<u8>,
        timestamp: u64,
    }

    struct FinalTokenMintedEvent has drop, store {
        mint_id: vector<u8>,
        account: address,
        amount: u128,
        solana_address: vector<u8>,
        timestamp: u64,
    }

    struct TokenMigrationStartedEvent has drop, store {
        account: address,
        amount: u128,
        solana_address: vector<u8>,
        timestamp: u64,
    }

    public fun mint(solana_address: vector<u8>, account: address, amount: u128) {
    }

    public fun mid_mint(mint_id: vector<u8>, solana_address: vector<u8>, to: address) {
    }

    public fun final_mint(mint_id: vector<u8>, solana_address: vector<u8>, to: address) {
    }

    public fun burn(solana_address: vector<u8>) {
    }

    public fun withdraw_eth() {
    }
}
