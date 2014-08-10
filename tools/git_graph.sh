for commit in $(git rev-list master)
do
  git checkout -q $commit
  git log -1 | head -3 | tail -1
  wc -l attract.asm
done
git checkout -q master
