#lang scribble/manual
@require[@for-label[inotify
                    racket/base]]

@title{Racket bindings for the Linux inotify API}
@author[@author+email["Shawn Wagner" "shawnw.mobile@gmail.com"]]

@defmodule[inotify]

Racket bindings for the Linux
@hyperlink["https://www.man7.org/linux/man-pages/man7/inotify.7.html"]{inotify
file system event monitor} API. A useful alternative to Racket's
native
@hyperlink["https://docs.racket-lang.org/reference/Filesystem.html?q=strerror#%28part._filesystem-change%29"]{file
system change events} API that offers finer control over what events
to be alerted about.

Currently only supported for 64-bit Racket.

It's basically the same workflow as the native C API: First create an
inotify descriptor/instance with @code{open-inotify-instance}, add
files to monitor for given events with @code{inotify-set-watch}, and
read @code{inotify-event}s with
@code{read-inotify-event}. @code{inotify-instance} objects are also
@code{sync}-able; their synchronization result is an
@code{inotify-event}.

@defproc[(inotify-instance? [obj any/c]) boolean?]{

Returns true if the given argument is an inotify instance.

}

@defproc[(open-inotify-instance) inotify-instance?]{

Returns a new inotify session instance.

Wrapper around the C @hyperlink["https://www.man7.org/linux/man-pages/man2/inotify_init.2.html"]{@tt{inotify_init(2)}} syscall.

}

@defproc[(close-inotify-instance [in inotify-instance?]) void?] {

Closes and frees operating system resources associated with the instance.

}


@defproc[(inotify-watch? [obj any/c]) boolean?]{

Returns true if the given argument is an inotify watch descriptor.

}

@defproc[(inotify-set-watch [in inotify-instance?] [file path-string?] [events (listof symbol?)]) inotify-watch?]{

Starts watching the given file for the given inotify events, which are
symbols with the same names as the C constants - @code{'IN_CREATE},
@code{'IN_MODIFY}, etc. Returns a watch descriptor object that can be
used to remove the watch, and used as a key for returned events.

Wrapper around the C @hyperlink["https://www.man7.org/linux/man-pages/man2/inotify_rm_watch.2.html"]{@tt{inotify_add_watch(2)}} syscall.

}

@defproc[(inotify-set-watch* [in inotify-instance?] [watches (listof (list/c path-string? (listof symbol?)))]) (listof inotify-watch?)]{

Adds all the given files and their desired events to the inotify watch list.

}

@defproc[(inotify-remove-watch [in inotify-instance?] [wd inotify-watch?]) void?]{

Removes the given watch descriptor from the inotify instance's monitored events.

Wrapper around the C @hyperlink["https://www.man7.org/linux/man-pages/man2/inotify_rm_watch.2.html"]{@tt{inotify_rm_watch(2)}} syscall.

}

@defproc*[([(call-with-inotify-instance [proc (-> inotify-instance? any)]) any]
           [(call-with-inotify-instance [watches (listof (list/c path-string? (listof symbol?)))] [proc (-> inotify-instance? (listof inotify-watch?) any)]) any])]{

Create an inotify instance and pass it to @code{proc}, optionally
creating the given watch instances and also passing them as a second
argument. The inotify instance is closed when @code{call-with-inotify-instance} returns. Returns the value(s) returned by @code{proc}.

}

@defstruct*[inotify-event ([wd inotify-watch?] [flags (listof symbol?)] [cookie exact-nonnegative-integer?] [name (or/c path? #f)])
                          #:transparent
                          #:omit-constructor]{

Information about a triggered watch event. Wrapper for the C
@tt{inotify_event} structure. Events are list of symbols instead of a
bitmask.

}

@defproc[(read-inotify-event [in inotify-instance?]) inotify-event?]{

Returns an inotify event, blocking until one is available if none are
currently pending.

}

@defproc[(read-inotify-event* [in inotify-instance?]) (or/c inotify-event? #f)]{

Returns an inotify event, or @code{#f} if none are currently pending.

}
