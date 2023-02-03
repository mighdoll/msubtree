`git msubtree` extends `git subtree` to support --rebase, so you can have a clean linear history for your monorepo.

<img width="882" alt="image" src="https://user-images.githubusercontent.com/63816/216511723-7c5bbe89-6503-451d-b1a9-4f4863077a2c.png">

`git msubtree` is nice way to support a monorepo:

- Users of the main repository and the subproject see their projects as
  normal git projects. (Users of the main repository see the entire project as monolithic.
  The subproject is just a directory.)
- You can transfer commits to and from external subproject repositories via subtree pull and push
  commands. Specially formatted git commit comments in the main repository mark the
  transfers.


## Install

Add this directory to your `$PATH`.
Then simply use `git msubtree` in place of `git subtree` to enable the new features.

`git msubtree` is like `git subtree`, but adds the `--rebase` option to the `msubtree` commands `add`, `pull` and `push`.

## Example Commands

add a new sub-repository into your monorepo:

```sh
git msubtree add --rebase --prefix=pkg/sub subrepo main
```

push changes from your monorepo to the sub-repository:

```sh
git msubtree push --rebase --prefix=pkg/sub subrepo main
```

pull changes from the sub-repository:

```sh
git msubtree pull --rebase --prefix=pkg/sub subrepo main
```


- ### Fixing Conflicts

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

- ### Aborting Conflicts
  - You can abandon the conflicted pull with:
    ```sh
    git msubtree pull --rebase --abort --prefix=pkg/sub subrepo main
    ```
    this will also do a git rebase --abort


## How it Works

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

`git-msubtree` is an extended version of the `git-subtree` script. 
The original merge based approach is used if `--rebase` is not specified.

## To Do
- implement `pull --abort`
- support `--squash` with `pull --rebase`. 
