/* User */
  
// Create a user
function User(profile_link, gravatar_id, git_username, real_name, repositories, new_user_flag) 
{
  this.profile_link = profile_link;
  this.gravatar= gravatar_id;
  this.username = git_username;
  this.real_name = real_name;
  this.repositories = repositories;
  this.seen_before = new_user_flag;
  
  // Checks if this user is an admin of the current repository context.
  this.is_admin = function(repo)
  {
    console.log(repo);
    
    if(this.repositories == undefined) return false;
    for(i = 0; i < repositories.length; i++)
    {
      if(this.repositores[i] == repo) return true;
    }
    
    return false;
  }
  
  return this;
}

  
