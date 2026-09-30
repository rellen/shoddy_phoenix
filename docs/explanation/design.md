# The design of ShoddyPhoenix

This page tells why ShoddyPhoenix is a separate library from Shoddy.

## Why a separate library

Shoddy has no runtime dependencies. Thus a library or a command-line tool
can use Shoddy, and it gets no other package.

Some tasks occur frequently only in Phoenix code. A function for such a task
needs Phoenix, or a dependency of Phoenix such as Plug. Shoddy must not
contain such a function, because each project that uses Shoddy then gets
Phoenix. These functions go into ShoddyPhoenix.

A Phoenix application already has Phoenix. Thus ShoddyPhoenix adds no other
package to it.

## The direction of the dependency

ShoddyPhoenix can have Shoddy as a dependency. Shoddy never has
ShoddyPhoenix as a dependency, because Shoddy must not get Phoenix.

## The same conventions

ShoddyPhoenix obeys
[the conventions of Shoddy](https://github.com/rellen/shoddy/blob/main/docs/reference/conventions.md).
A person who knows one library then knows the rules of the other. For
example, the first argument of each function is the value that the function
operates on, such as a `Plug.Conn` struct.
