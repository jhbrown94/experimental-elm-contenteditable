module MutationObserver exposing (AttributesRep, CharacterDataRep, ChildListRep, MutationRecord(..), NodeRefList)


type MutationRecord
    = Attributes AttributesRep
    | CharacterData CharacterDataRep
    | ChildList ChildListRep


type alias AttributesRep =
    { attributeName : String
    , attributeValue : Maybe String
    }


type alias ChildListRep =
    { addedNodes : List NodeRef
    , removedNodes : List NodeRef
    , previousSibling : Maybe NodeRef
    , nextSibling : Maybe NodeRef
    }


type alias CharacterDataRep =
    { text : String
    }
