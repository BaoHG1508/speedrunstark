use starknet::ContractAddress;
#[starknet::interface]
pub trait IVendor<T> {
    fn buy_tokens(ref self: T, eth_amount_wei: u256);
    fn withdraw(ref self: T);
    fn sell_tokens(ref self: T, amount_tokens: u256);
    fn tokens_per_eth(self: @T) -> u256;
    fn your_token(self: @T) -> ContractAddress;
    fn eth_token(self: @T) -> ContractAddress;
}

#[starknet::contract]
mod Vendor {
    use contracts::YourToken::{IYourTokenDispatcher, IYourTokenDispatcherTrait};
    use core::traits::TryInto;
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_access::ownable::interface::IOwnable;
    use openzeppelin_token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};
    use starknet::{get_caller_address, get_contract_address};
    use super::{ContractAddress, IVendor};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    // ToDo Checkpoint 2: Define const TokensPerEth
    const TokensPerEth: u256 = 100;

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        eth_token: IERC20CamelDispatcher,
        your_token: IYourTokenDispatcher,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        BuyTokens: BuyTokens,
        SellTokens: SellTokens,
    }

    #[derive(Drop, starknet::Event)]
    struct BuyTokens {
        buyer: ContractAddress,
        eth_amount: u256,
        tokens_amount: u256,
    }

    //  ToDo Checkpoint 3: Define the event SellTokens
    #[derive(Drop, starknet::Event)]
    struct SellTokens {
        seller: ContractAddress,
        eth_amount: u256,
        tokens_amount: u256,
    }

    #[constructor]
    // Todo Checkpoint 2: Edit the constructor to initialize the owner of the contract.
    fn constructor(
        ref self: ContractState,
        eth_token_address: ContractAddress,
        your_token_address: ContractAddress,
        owner: ContractAddress,
    ) {
        self.eth_token.write(IERC20CamelDispatcher { contract_address: eth_token_address });
        self.your_token.write(IYourTokenDispatcher { contract_address: your_token_address });
        // ToDo Checkpoint 2: Initialize the owner of the contract here.
        self.ownable.initializer(owner);
    }
    #[abi(embed_v0)]
    impl VendorImpl of IVendor<ContractState> {
        // ToDo Checkpoint 2: Implement your function buy_tokens here.
        fn buy_tokens(
            ref self: ContractState, eth_amount_wei: u256,
        ) { // Note: In UI and Debug contract `buyer` should call `approve`` before to `transfer` the amount to the `Vendor` contract.            
            assert(self.eth_token.read().balanceOf(get_caller_address()) >= eth_amount_wei, 'Not enough eth');
            assert(self.your_token.read().balance_of(get_contract_address()) >= eth_amount_wei * TokensPerEth, 'Not enough tokens');

            self.eth_token.read().transferFrom(get_caller_address(), get_contract_address(), eth_amount_wei);
            self.your_token.read().transfer(get_caller_address(), eth_amount_wei * TokensPerEth);

            self.emit(BuyTokens {
                buyer: get_caller_address(),
                eth_amount: eth_amount_wei,
                tokens_amount: eth_amount_wei * TokensPerEth,
            });
        }

        // ToDo Checkpoint 2: Implement your function withdraw here.

        fn withdraw(ref self: ContractState) {
            assert(self.ownable.owner() == get_caller_address(), 'Not authorized');
            assert(self.eth_token.read().balanceOf(get_contract_address()) > 0, 'Not enough eth');

            self.eth_token.read().transfer(get_caller_address(), self.eth_token.read().balanceOf(get_contract_address()));
        }

        // ToDo Checkpoint 3: Implement your function sell_tokens here.
        fn sell_tokens(ref self: ContractState, amount_tokens: u256) {
            // Input validation
            assert(amount_tokens > 0, 'Amount must be greater than 0');

            // Calculate ETH amount to return
            let eth_amount = amount_tokens / TokensPerEth;
            let token_dispatcher = self.your_token.read();
            let eth_dispatcher = self.eth_token.read();
            let contract_address = get_contract_address();

            // Check seller's token balance and allowance
            let seller = get_caller_address();
            assert(token_dispatcher.balance_of(seller) >= amount_tokens, 'Insufficient token balance');
            assert(token_dispatcher.allowance(seller, contract_address) >= amount_tokens, 'Insufficient token allowance');

            // Check vendor's ETH balance
            assert(eth_dispatcher.balanceOf(contract_address) >= eth_amount, 'Insufficient ETH balance');
            
            token_dispatcher.transfer_from(seller, contract_address, amount_tokens);
            eth_dispatcher.transfer(seller, eth_amount);
            
            // Emit event
            self.emit(SellTokens {
                seller,
                tokens_amount: amount_tokens,
                eth_amount,
            });
        }

        // ToDo Checkpoint 2: Modify to return the amount of tokens per 1 ETH.
        fn tokens_per_eth(self: @ContractState) -> u256 {
            TokensPerEth
        }

        fn your_token(self: @ContractState) -> ContractAddress {
            self.your_token.read().contract_address
        }

        fn eth_token(self: @ContractState) -> ContractAddress {
            self.eth_token.read().contract_address
        }
    }
}
