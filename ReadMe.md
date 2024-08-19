aptos init --network testnet
aptos account create-resource-account --seed 1

profile 是本地测试使用

aptos move compile --package-dir pepePong_Move --named-addresses pong_addr=xxx

aptos move publish --package-dir /home/cxgd/opensourcePj/pingPong_Move/pepePong_Move --named-addresses pong_addr=xxx

aptos move create-object-and-publish-package --address-name pong_addr --named-addresses pong_addr=xxx --profile xxx

aptos move create-resource-account-and-publish-package --address-name pong_addr --seed 1
aptos move compile --named-addresses pong_addr=xxx
