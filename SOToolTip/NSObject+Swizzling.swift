import Foundation

// -------------------------------------
/**
 Data structure to use a `Dictionary.Key` for mapping a class and swizzled
 selector to its previous implementation
 */
fileprivate struct IMPMapKey: Hashable
{
    let classType: AnyClass
    let selector: Selector
    
    static func == (left: Self, right: Self) -> Bool
    {
        return left.classType == right.classType
            && left.selector == right.selector
    }
    
    func hash(into hasher: inout Hasher)
    {
        hasher.combine(classType.description())
        hasher.combine(selector)
    }
}

/**
 `Dictionary` mapping class-selector combinations to their corresponding
 previous implementation.
 */
fileprivate var implementationMap: [IMPMapKey: IMP] = [:]

// MARK:- NSObject extension
// -------------------------------------
extension NSObject
{
    // -------------------------------------
    /**
     Get the previous implementation for `selector` or `nil` if `selector` has
     no previous implementation (possible it wasn't swizzled).
     */
    static func implementation(for selector: Selector) -> IMP?
    {
        let key = IMPMapKey(classType: Self.self, selector: selector)
        return implementationMap[key]
    }
    
    // -------------------------------------
    /**
     Replace the implementation of `oldSelector` with the implementation of
     `newSelector`.  It's up to the new implemenatoin to forward to the old
     one.
     
     If `oldSelector` is not implemented,, it will be added using
     `newSelector`'s implementation.
     
     - Parameters:
        - oldSelector: `Selector` for existing method whose implementation is
            to be replaced.
        - newSelector: `Selector` of the method whose implementaton will be
            used to replace `oldSelector`'s implementation.
     */
    static func replaceMethod(
        _ oldSelector: Selector,
        with newSelector: Selector)
    {
        guard let newMethod = instanceMethod(for: newSelector) else {
            fatalError("Failed to get implementation for \(newSelector)")
        }
        
        let newImp = method_getImplementation(newMethod)
        if let oldImp = replaceSelectorImplementation(
            selector: oldSelector,
            newImplementation: newImp)
        {
            let key = IMPMapKey(classType: Self.self, selector: oldSelector)
            implementationMap[key] = oldImp
        }
    }
    
    // -------------------------------------
    /**
     Replaces the implementation of the method specified by `Selector` in the receiving `class` with `newImplementation`.
     
     - Note: `IMP` is an Objective-C runtime type.  It is an `OpaquePointer` to
        a C function.
     
     - Parameters:
        - selector: The `Selector` whose corresponding method's implementation
            will be replaced by `newImplementation`.
        - newImplementation: The implmenetation, specified as an `IMP`, to
            replace the implementation for `Selector`.
     - Returns: The previous implementation of `Selector` or `nil` if there
        isn't one.
     */
    private static func replaceSelectorImplementation(
        selector: Selector,
        newImplementation: IMP) -> IMP?
    {
        print("Swizzling \(Self.self).\(selector)")
        guard self.superclass() != nil else {
            fatalError("Swizzling NSObject itself - don't do that")
        }
        
        guard let method = instanceMethod(for: selector) else {
            fatalError("Failed to get implementation for \(selector)")
        }
        
        /*
         If the method already exists, we can just replace it, because we'll
         chain to its old implementaton.  If it doesn't exist, then we need to
         add one to call super first
         */
        let types = method_getTypeEncoding(method)
        addMethodThatCallsSuper(Self.self, selector, types)
        let oldImp = class_replaceMethod(
            Self.self,
            selector,
            newImplementation,
            types
        )

        return oldImp
    }
    
    // -------------------------------------
    /**
     Convenience function for obtaining the `METHOD` associated with `seletor` for the receiving class.
     
     - Parameter selector: The `Selector` whose `METHOD` is to be returned.
     - Returns: A `METHOD` for `selector` when applied to the receiving class,
        or `nil` if that `selector` is not implemented.
     - Note: `METHOD` is an opaque Objective-C runtime type representing a
        method definition.
     */
    private static func instanceMethod(for selector: Selector) -> Method? {
        return class_getInstanceMethod(Self.self, selector)
    }
}
