use arm::encryption::{random_keypair, Ciphertext, SecretKey};
use bincode;
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
    at_keypair_key = "Elixir.Anoma.LocalDomain.Keypair "
}

impl Encoder for Keypair {
    fn encode<'a>(&self, env: Env<'a>) -> Term<'a> {
        let secret_key_bytes: Vec<u8> = self.secret.inner().to_bytes().to_vec();
        let public_key_bytes: Vec<u8> = bincode::serialize(&self.public).expect("fuck off");

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
        let public_term = term.map_get(at_public_key().encode(term.get_env()))?;
        let public_key_bytes: Vec<u8> = public_term.decode()?;

        let secret = SecretKey::new(Scalar::from_repr(secret_key_slice.into()).unwrap());

        let public: AffinePoint = bincode::deserialize(&public_key_bytes.as_slice()).unwrap();
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
pub fn test_key_pair(keypair: Keypair) -> Keypair {
    keypair
}

#[nif]
pub fn decrypt_cipher(cipher_bytes: Vec<u8>, keypair: Keypair) -> Option<Vec<u8>> {
    let cipher_text = Ciphertext::from_bytes(cipher_bytes);
    let decipher_result = Ciphertext::decrypt(&cipher_text, &keypair.secret);
    decipher_result.ok()
}

rustler::init!("Elixir.Anoma.LocalDomain.ArmBindings");
