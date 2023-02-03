git msubtree extends git subtree to support --rebase, so you can have a clean linear history for your monorepo.

```
*   c86f090 Split 'pkg/sub/' into c..
|\  
| * 2e63d7e modify 2 from main       
* | 581eadc modify 2 from main       
* | bfa05c7 Merge commit '59e898a75..
|\| 
| * 59e898a modify 1 from sub        
* | 0be8862 Merge commit '3dde001e1..
|\| 
| * 3dde001 modify 0 from sub        
* | 56c3d54 Add 'pkg/sub/' from com..
|\| 
| * e872c06 initial commit sub       
* e4e00d4 initial commit main
```

```
* 2675b5f rebase push from pkg/sub 
* 16c0aef modify 2 from main       
* 1cc97dd rebase pull into pkg/sub 
* c04d9c6 modify 1 from sub        
* 27db782 rebase pull into pkg/sub 
* b930cee modify 0 from sub        
* 2f82a7a Add 'pkg/sub/' from com..
* 3371498 initial commit main
```

git-subtree is one of the best ways to support a monorepo with git:

- Users of the main repository and the subproject see their projects as
  normal git projects. (Users of the main repository see the entire project as monolithic,
  the subproject is just a directory.)
- You can transfer commits to and from external subproject repositories via subtree pull and push
  commands. Specially formatted git commit comments in the main repository mark the
  transfers.

`git msubtree` works like subtree, but adds the --rebase option to the commands add, pull and push.

## Install

Add this directory to your `$PATH`.
Then simply use `git msubtree` in place of `git subtree` to enable the new features.

## Example Use

### add

```sh
git msubtree add --rebase --prefix=pkg/sub subrepo main
```

### push

```sh
git msubtree push --rebase --prefix=pkg/sub subrepo main
```

### pull

```sh
git msubtree pull --rebase --prefix=pkg/sub subrepo main
```

<style type="text/css" rel="stylesheet">
.no_bullets li { list-style: none; }
</style>

<div class="no_bullets">

- ### fixing conflicts
  - Fix the files, and `git rebase --continue` until there are no more conflicts:

    ```sh
    git add .
    git commit -a -m "fixed conflict"
    git rebase --continue
    ```

  - And then finish the subtree operations with `msubtree pull --continue`:

    ```sh
    git msubtree pull --rebase --continue --prefix=pkg/sub subrepo main
    ```

- ### aborting conflicts
  * You can abandon the conflicted pull with:
    ```sh
    git msubtree pull --rebase --abort --prefix=pkg/sub subrepo main
    ```
    this will also do a git rebase --abort

</div>

## How it works

`msubtree` can translate commits between the subtree repository and main repo.
Once translated, commits can be pulled or pushed between the two repositories.

After a pull or push (or add) the contents of the subtree directory in the two
repositories will typically match exactly. `msubtree` will record a
commit in the main repository with a formatted comment describing this 'sync point':
the hashes of the most recent pair of commits from the main and subtree repositories
referencing the identical subtree directory content.

The sync point is used for future operations to reduce unnecessary conflicts, and to optimize 
unnecessary scanning.

If files have been edited in both repositories, the sync point may not be the most recent commit
in the main or subtree repositories, but `msubtree` will search for the most recent sync
point it can find.

## To Do
* implement `pull --abort` 
* support `--squash` with `pull --rebase`.  (`add --rebase` squashes by default.)
