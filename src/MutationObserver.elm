module MutationObserver exposing (AttributesRep, CharacterDataRep, ChildListRep, MutationRecord(..), NodeRef(..), NodeRefList)


type MutationRecord
    = Attributes AttributesRep
    | CharacterData
    | ChildList ChildListRep


type alias AttributesRep =
    { target : NodeRef
    , attributeName : String
    , attributeValue : String
    }


type alias ChildListRep =
    { target : NodeRef
    , addedNodes : NodeRefList
    , removedNodes : NodeRefList
    , previousSibling : Maybe NodeRef
    , nextSibling : Maybe NodeRef
    }


type alias CharacterDataRep =
    { target : NodeRef
    , text : String
    }


type NodeRef
    = NodeId String
    | NodePath NodeRef Int


type alias NodeRefList =
    List NodeRef
