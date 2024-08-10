# Lang

C / Rust like low-level language

## Data Types

u8, u16, u32, str

## Operators

+, -, *, /, %, &, |, ^, <<, >>, !

## Functions

fn add(a: u16, b: u36): u16 {
    a + b
}

## Control Flow

if a > b {
    a
} else {
    b
}

## Loops

while a < b {
    a += 1
}

for i in 0..10 {
    ...
}

## Pointers

let addr: *u16 = 0x1234

*addr = 0x5678

## Structs

struct Point {
    x: u16,
    y: u16,
}

fn Point::add(&self, p: Point) -> Point {
    Point { x: self.x + p.x, y: self.y + p.y }
}

let p = Point { x: 10, y: 20 }
let q = p.add(Point { x: 30, y: 40 })
