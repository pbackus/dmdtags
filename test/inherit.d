class Base {}
interface I1 {}
interface I2 {}
interface I3 : I2 {}
class Derived : I3, Base, I1 {}
