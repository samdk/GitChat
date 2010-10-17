/* Commit */

// Create a Commit
function Commit(hash, repository, commit_msg, author, date, branch)
{
  this.hash = hash;
  this.repository = repository;
  this.commit_msg = commit_msg;
  this.author = author;
  this.date = date
  this.branch = branch
  
  return this;
}
