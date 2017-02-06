# keys-generator
XORed API keys generator for your Swift app

## Purpose
Often iOS apps contain various keys such as: SDK client ID, SDK secret key and so on. Raw strings can be easily found by `strings` or Hopper and therefore accessible to nearly anyone. Easiest way out is to (at least) XOR those keys. Purpose of this script is to XOR the given keys and output a Swift `enum` with encrypted values under the hood. 

> IMPORANT: This tool doesn't prevent your strings from being stolen by a praying eyes. All it does is hide strings from being discovered by the 'strings' utility or by a disassembler. Therefore **it is strongly not recommended to put sensitive data like S3 secret key in your app at all** - rather hide them behind you server's API and do not pass over the network in any circumstances.

## Usage
* You start by creating a `json` file containing desired keys: 
```json
{
  "soundcloudClientID": "Nhu23d6zlDKR1P6CgEmKzgsdM4CpZrGXlR",
  "soundcloudSecretKey": "3cIzDM4HfyelKuzeOPZrQf9941X0sdnO"
}
```

* Then you should add invocation of the `keys-generator.rb` to the build phases right after `Target Dependencies`. 
* Pass correct arguments to the script: keys-generator.rb accepts following options: 
  - --keys=absolute_path: Path to the .json file that contains dictionary of the keys that needs to be XORed.
  - --output=absolute_path: Output directory for the generated file.
  - --xor_key: Key used for XORing.
  - --name: (optional) Name of the desired generated enum with keys. Default is StaticKey.

Example invocation might look like this: 
```shell
/usr/bin/ruby "${SRCROOT}/scripts/keys-generator.rb" --keys="${SRCROOT}/resources/api_keys.json" --output="${SRCROOT}" --xor_key="${PRODUCT_BUNDLE_IDENTIFIER}"
```

Outcome of such invocation is the `StaticKey.swift` file in the `${SRCROOT}` directory:
```swift
public enum StaticKey {
	case soundcloudClientID
	case soundcloudSecretKey

	public var value: String { /* actual decoding done here*/ }
}
```

As the result you can use a generated `enum` in the following way:
```swift
// somewhere in the app delegate 
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
  SoundcloudSDK.setClientID(StaticKey.soundcloudClientID.value, secret: StaticKey.soundcloudSecretKey.value)

  // more stuff comes here

  return true
}
```

## Troubleshooting
`'require': cannot load such file -- claide`
In case your `gem` path differs from the default one (rbenv or rvm runnning a different version of ruby) - you have to provide the path to the current version of the ruby (to the `rbenv global`). It turns out that Xcode have a different `$PATH` variable that doesn't include rbenv or rvm's changes. One way to fix is to run a `.profile` or a `.bash_profile` that modifies your `$PATH` variable: 
```shell
source $HOME/.profile
ruby "${SRCROOT}/scripts/keys-generator.rb" ... 
```
