/* Issues */

// Create an issue
function Issue(creator, title, text, github_id, repo, closer, close_msg, created_date, closed_date)
{
  this.creator = creator;
  this.title = title;
  this.text = text;
  this.github_id = github_id;
  this.repo = repo;
  this.closer = closer;
  this.close_msg = close_msg;
  this.created_date = created_date;
  this.closed_date = closed_date;
  
  return this;
}
