#ifndef swizzleHelper_h
#define swizzleHelper_h

#import <objc/runtime.h>
#import <objc/NSObject.h>

// -------------------------------------
/**
 @abstract Add an instance method to `cls` that forwards to it's `super`
 
 @discussion The method will be added only if it doesn't already exist.
 
 @param cls Class to which to add the instance method to call to super
 @param selector selector for the method to add the call to super
 @param types Objective-C type encoding string to used idefining the method.
 
 @returns `TRUE` if the method was added., or `FALSE` if it wasn't.
 */
BOOL addMethodThatCallsSuper(
    Class  _Nonnull __unsafe_unretained cls,
    SEL _Nonnull selector,
    const char* _Nullable types);


// -------------------------------------
/*!
 @abstract Call the functoin specified by `imp` passing the `receiver` and
 `selector`with no other parameters.
 @param imp the implementation function to be called
 @param receiver the receiver of the implementatoin call
 @param selector the selector to be used for the implemenation call.
 */
void callIMP(
    IMP _Nonnull imp,
    _Nonnull __unsafe_unretained id receiver,
    _Nonnull SEL selector);

// -------------------------------------
/*!
 @abstract Call the functoin specified by `imp` passing the `receiver`,
 `selector`, and a pointer to an `NSObject`.
 @param imp the implementation function to be called
 @param receiver the receiver of the implementatoin call
 @param selector the selector to be used for the implemenation call.
 @param param the `NSObject` to pass as a parameter in the implementation call.
 */
void callIMP_withObject(
     IMP _Nonnull imp,
     __unsafe_unretained id _Nonnull receiver,
     _Nonnull SEL selector,
     NSObject* _Nullable param);

// -------------------------------------
/*!
 @abstract Call the functoin specified by `imp` passing the `receiver`,
 `selector`, and a void pointer
 @param imp the implementation function to be called
 @param receiver the receiver of the implementatoin call
 @param selector the selector to be used for the implemenation call.
 @param param the `void *` to pass as a parameter in the implementation call.
 */
void callIMP_withPointer(
    IMP _Nonnull imp,
    __unsafe_unretained id _Nonnull receiver,
    _Nonnull SEL selector,
    const void * _Nullable param);


#endif /* swizzleHelper_h */
