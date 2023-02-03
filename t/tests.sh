#!/bin/sh 

test_text=0
root_dir="$(pwd)"
PATH="$root_dir:$PATH"
quiet_tests=1
do_rebase="--rebase"

##
## -----  tests -------
##

run_all_tests () {
  run_test "add"
  run_test "simple_pull"
  run_test "pull_continue"
  run_test "pull_abort"
  run_test "simple_push"
  run_test "push_after_continue"
}

# test that add --rebase works
test_add () {
  make_bare_repos
  modify_sub
  msubtree_add

  cd main
  git log --oneline --parents
  verify_no_merges
  verify_equal "$(last_commit_subject 1)" "initial commit main"  
  
  cd ..
}

# verify that pull --rebase works
test_simple_pull () {
  make_repos
  modify_sub
  msubtree_pull 
  cd main
  verify_equal "$(last_commit_subject 0)" "rebase pull into pkg/sub"  
  verify_equal "$(last_commit_subject 1)" "modify 0 from sub"  
  cd ..
}

# verify that push --rebase works
test_simple_push () {
  make_repos
  modify_main
  msubtree_push

  cd sub
  git checkout -q main
  verify_equal "$(last_commit_subject 0)" "modify 0 from main"  
  git checkout -q foo
  cd ..

  cd main
  verify_equal "$(last_commit_subject 0)" "rebase push from pkg/sub"  
  cd ..
}

# verify that pull --abort works after a conflict
test_pull_abort () {
  make_repos
  modify_main
  modify_sub
  msubtree_pull 
  msubtree_pull_abort 

  cd main
  verify_equal "$(last_commit_subject 0)" "modify 0 from main"  
  rebasing=$(git rev-parse -q --verify REBASE_HEAD)
  verify_equal "$rebasing" ""
  cd ..
}

# verify that pull --continue works after a conflict
test_pull_continue () {
  make_repos
  modify_main
  modify_sub
  msubtree_pull 

  # resolve conflict
  cd main
  echo "resolved conflict on main" > pkg/sub/sub.txt
  git add pkg/sub/sub.txt
  EDITOR='f () {
    cp $1 /tmp/foo.$$
    awk "BEGIN {ORS=\"\"; print \"(conflict resolved) \"; ORS=\"\\n\";}; {print \$0}" /tmp/foo.$$ > $1
    rm /tmp/foo.$$
  }; f' 
  export EDITOR
  git rebase --continue 
  cd ..

  msubtree_pull_continue

  cd main
  verify_equal "$(last_commit_subject 0)" "(conflict resolved) modify 1 from sub"  
  verify_equal "$(last_commit_subject 1)" "modify 0 from main"  
  cd ..
}

# verify that push works after a conflict resolved with pull --continue
test_push_after_continue () {
  test_pull_continue

  msubtree_push

  cd sub
  git checkout -q main
  verify_equal "$(cat sub.txt)" "resolved conflict on main"  
  verify_equal "$(last_commit_subject 0)" "(conflict resolved) modify 1 from sub"  
  git checkout -q foo
  cd ..
}

#
# -----  tests for documentation  ------
#

test_example_merge () {
  do_rebase=""
  test_example
  do_rebase="--rebase"
}

test_example() {
  make_repos
  modify_sub
  msubtree_pull
  modify_sub
  msubtree_pull
  modify_main
  msubtree_push

  cd main
  git log --graph --pretty=format:"%h %<(25,trunc)%s" 
  cd ..
}


##  
##  -----   msubtree commands  -------
##  

msubtree_add () {
  cd main
  git msubtree add $do_rebase --prefix=pkg/sub ../sub main
  cd ..
}

msubtree_pull () {
  cd main
  git msubtree pull $do_rebase --prefix=pkg/sub ../sub main
  cd ..
}

msubtree_pull_continue () {
  cd main
  git msubtree pull --continue --prefix=pkg/sub ../sub main
  cd ..
}

msubtree_pull_abort () {
  cd main
  git msubtree pull --abort 
  cd ..
}


#
# --- test setup --
#

make_repos () {
  make_bare_repos
  # add the subtree
  msubtree_add
}

make_bare_repos () {
  # clear from previous runs
  rm -rf temp || 0
  test_text=0

  # make main repo
  mkdir -p temp/main/pkg
  cd temp/main
  git init -q
  touch main.txt
  git add main.txt
  git commit -a -q -m "initial commit main"
  cd ..

  # make sub repo
  mkdir -p sub
  cd sub
  git init -q
  touch sub.txt
  git add sub.txt
  git commit -a -q -m "initial commit sub"
  git checkout -q -b foo
  cd ..
}

msubtree_push() {
  cd main
  
  rebase_rejoin=$do_rebase
  if test -z $rebase_rejoin
  then
    rebase_rejoin="--rejoin"
  fi

  git msubtree push $rebase_rejoin --prefix=pkg/sub ../sub main
  cd ..
}

modify_main () {
  cd main
  message="modify $test_text from main"
  ((test_text++))
  echo $message >> pkg/sub/sub.txt
  git add pkg/sub/sub.txt
  git commit -q -m "$message" pkg/sub/sub.txt 
  cd ..
}

modify_sub () {
  cd sub
  git checkout -q main
  message="modify $test_text from sub"
  ((test_text++))
  echo $message >> sub.txt
  git add sub.txt
  git commit sub.txt -q -m "$message"
  git checkout -q foo
  cd ..
}

##  
##  -----   test assertions -------
##  

verify_no_merges () {
  git rev-list --parents HEAD |
  while read commit parent1 parent2
  do 
    if test -n "$parent2"
    then
      echo "ERROR: created a merge commit"
      exit 1
    fi
  done
  result=$? # exit code of the while loop
  if test $result -ne 0
  then
    echo "exiting $result"
    exit $result
  fi
}

last_commit_subject () {
  if test $# -eq 0
  then
    nth=0
  else
    nth=$1
  fi 
	git log -1 --pretty=format:%s HEAD~$nth 
}

# Fail if arguments are not equal
verify_equal () {
  arg1="$1"
  arg2="$2"
  if test "$arg1" != "$arg2"
  then
    echo "ERROR" $arg1 "!=" $arg2
    exit 1
  fi
}

# debug utility
log_repos () {
  echo "main line:"
  cd main
  git log --oneline
  cd ..

  cd sub 
  echo "sub line:"
  git checkout -q main
  git log --oneline
  git checkout -q foo
  cd ..
}

##  
##  -----   test mechanics -------
##  

run_test () {
  test_name=test_$1
  if test $quiet_tests -eq 1
  then
    $($test_name > /dev/null 2>&1)
    result=$?
  else 
    #subtree add isn't happy in a subshell, so we just fail if necessary
    $test_name 
    result=$?
  fi
  if test $result -ne 0
  then
    echo "FAIL: $test_name"
    exit 1
  else
    echo "PASS: $test_name"
  fi
}

main () {
  if test "$1" = "-v"
  then
    quiet_tests=0
    shift
  fi

  if test $# -eq 0
  then
    run_all_tests
  else
    run_test $1
  fi
}


main "$@"