# `multiselect.vim`

`multiselect.vim` is a utility plugin that adds a single function `multiselect#open`, which takes a
config and a list of strings and opens a new buffer containing those strings as items in a
checklist.

This buffer has no file associated with it and when you save it, instead of writing the contents to
a file, it calls the configured callback functions based on which items have been checked or
unchecked. It mostly exists to support a couple of other plugins I wrote (`bufedit.vim` and
`workflow.vim`).

By default, checked items are removed from the list on save, but if you set `'keepchecked': 1` you
can also set an `'onnewunchecked'` callback, which fires for all items that are newly unchecked.

Supported callback functions are:

* `'onchecked'`: this is called on each checked item
* `'onnewchecked'`: this is called on each newly checked item, but not on items that were already
  checked before the current save.
* `'onunchecked'`: this is called on each unchecked item
* `'onnewunchecked'`: this is called on each newly checked item, but not on items that were already
  checked before the current save.
