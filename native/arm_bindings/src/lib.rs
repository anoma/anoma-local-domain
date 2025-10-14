use arm::encryption::{random_keypair, Ciphertext, SecretKey};
use bincode;
use k256::elliptic_curve::group::GroupEncoding;
use k256::elliptic_curve::PrimeField;
use k256::{AffinePoint, Scalar};
use rustler::types::map::map_new;
use rustler::{atoms, nif, Decoder, Encoder, Env, NifResult, Term};

/// A Keypair is a struct that holds a SecretKey and Affinepoint.
/// It is used here to implement the Encoder and RusterEncoder trait.
/// The encoded value is a tuple.
pub struct Keypair {
    pub secret: SecretKey,
    pub public: AffinePoint,
}

atoms! {
    at_struct = "__struct__",
    at_secret_key = "secret_key",
    at_public_key = "public_key",
    at_keypair_key = "Elixir.AnomaSDK.Arm.Keypair"
}

impl Encoder for Keypair {
    fn encode<'a>(&self, env: Env<'a>) -> Term<'a> {
        let secret_key_bytes: Vec<u8> = self.secret.inner().to_bytes().to_vec();
        let public_key_bytes: Vec<u8> = self.public.to_bytes().to_vec();

        map_new(env)
            .map_put(at_struct().encode(env), at_keypair_key())
            .unwrap()
            .map_put(at_secret_key(), secret_key_bytes.encode(env))
            .unwrap()
            .map_put(at_public_key(), public_key_bytes.encode(env))
            .expect("failed to encode Keypair")
    }
}

impl<'a> Decoder<'a> for Keypair {
    fn decode(term: Term<'a>) -> NifResult<Self> {
        let secret_term = term.map_get(at_secret_key().encode(term.get_env()))?;
        let secret_key_bytes: Vec<u8> = secret_term.decode()?;
        let secret_key_slice: [u8; 32] = secret_key_bytes.try_into().unwrap();
        let secret = SecretKey::new(Scalar::from_repr(secret_key_slice.into()).unwrap());

        let public_term = term.map_get(at_public_key().encode(term.get_env()))?;
        let public_key_bytes: Vec<u8> = public_term.decode()?;
        let public: AffinePoint = bincode::deserialize(public_key_bytes.as_slice())
            .map_err(|_| rustler::Error::BadArg)?;
        Ok(Keypair { secret, public })
    }
}

#[nif]
/// Generates a random pair of SecretKey and AffinePoint.
pub fn random_key_pair() -> Keypair {
    let (secret, public) = random_keypair();
    Keypair { secret, public }
}

#[nif]
pub fn decrypt_cipher(cipher_bytes: Vec<u8>, keypair: Keypair) -> Option<Vec<u8>> {
    let discovery_sk_bytes: [u8; 32] = [
        80, 35, 79, 155, 117, 210, 75, 68, 253, 197, 65, 105, 156, 112, 246, 55, 104, 248, 233, 99,
        118, 94, 175, 57, 215, 34, 142, 101, 221, 197, 125, 134,
    ];
    let discovery_sk: SecretKey =
        bincode::deserialize(discovery_sk_bytes.as_ref()).expect("failed to decode discovery_sk");
    let discovery_pk_bytes: [u8; 41] = [
        33, 0, 0, 0, 0, 0, 0, 0, 3, 199, 253, 168, 54, 100, 229, 223, 178, 183, 122, 215, 44, 100,
        12, 121, 62, 212, 135, 205, 169, 150, 92, 196, 142, 239, 58, 60, 109, 59, 71, 235, 96,
    ];
    let discovery_pk: AffinePoint =
        bincode::deserialize(discovery_pk_bytes.as_ref()).expect("failed to decode discovery_pk");

    let alice = Keypair {
        secret: discovery_sk,
        public: discovery_pk,
    };
    assert_eq!(keypair.public, alice.public);
    assert_eq!(keypair.secret.inner(), alice.secret.inner());

    println!("cipher bytes: {:?}", cipher_bytes);
    println!("secret key: {:?}", keypair.secret);
    println!("public key: {:?}", keypair.public);

    let cipher_text = Ciphertext::from_bytes(cipher_bytes.clone());
    println!("incoming ciphertext: {:?}", cipher_text);
    println!("cipher_bytes ciphertext: {:?}", cipher_bytes);

    let decipher_result = cipher_text.decrypt(&keypair.secret);
    println!("decipher result {:?}", decipher_result);
    decipher_result.ok()
}

rustler::init!("Elixir.Anoma.LocalDomain.ArmBindings");
