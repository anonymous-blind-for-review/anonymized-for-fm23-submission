{- Byzantine Fault Tolerant Consensus Verification in Agda, version 0.9.

   Copyright (c) 2021, Oracle and/or its affiliates.
   Licensed under the Universal Permissive License v 1.0 as shown at https://opensource.oracle.com/licenses/upl
-}

open import LibraBFT.ImplShared.Consensus.Types
open import Optics.All
open import Util.Encode
open import Util.PKCS                            as PKCS hiding (sign)
open import Util.Prelude

module LibraBFT.Impl.Types.ValidatorSigner where

sign : {C : Set} ⦃ enc : Encoder C ⦄ → ValidatorSigner → C → Signature
sign (ValidatorSigner∙new _ sk) c = PKCS.sign-encodable c sk

postulate -- TODO-1: publicKey_USE_ONLY_AT_INIT
  publicKey_USE_ONLY_AT_INIT : ValidatorSigner → PK

obmGetValidatorSigner : AuthorName → List ValidatorSigner → Either ErrLog ValidatorSigner
obmGetValidatorSigner name vss =
  case List-filter go vss of λ where
    (vs ∷ []) → pure vs
    _         → Left fakeErr -- [ "ValidatorSigner", "obmGetValidatorSigner"
                             -- , name , "not found in"
                             -- , show (fmap (^.vsAuthor.aAuthorName) vss) ]
 where
  go : (vs : ValidatorSigner) → Dec (vs ^∙ vsAuthor ≡ name)
  go (ValidatorSigner∙new _vsAuthor _) = _vsAuthor ≟ name


