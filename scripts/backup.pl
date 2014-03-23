#!/usr/bin/perl

use JSON qw( decode_json );
use POSIX qw(strftime);
use Capture::Tiny ':all';

my $IDENTITY_LOCATION = "/home/backup_manager/.ssh/id_rsa";
my $LOG = "/home/backup_manager/verbose_log";
my $BASE_DIR = "/home/backup_manager/";
my $SCRIPTS_DIR = $BASE_DIR."scripts/";
my $CONFIG_LOCATION = $BASE_DIR."configs";
my $EXCLUDE_LOCATION = $BASE_DIR."configs/excludes";
my $BACKUP_COMMAND = "/usr/bin/rsync --compress --rsh=ssh --times --ignore-times --links --perms \\
               --recursive --size-only --delete --force --numeric-ids --exclude-from={EXCLUDE_FILES} \\
	       -e 'ssh  -i $IDENTITY_LOCATION' \\
               --stats {LOCAL_BACKUP_FILES} {REMOTE_BACKUP_USER}\@{REMOTE_BACKUP_SERVER}:{REMOTE_BACKUP_LOCATION}";


my @config_files = ();
{
  opendir(MYDIR, $CONFIG_LOCATION);
  @config_files = grep {/\.conf$/} readdir(MYDIR);
  closedir(MYDIR);
}

for my $conf (@config_files)
{
  my $emailErrors = "";
  local $/=undef;
  open FILE, $CONFIG_LOCATION."/".$conf or die "Couldn't open file: $!";
  my $config = <FILE>;
  close FILE;
  $config = decode_json( $config );
  
  for my $backup (@{$config->{backup}})
  {
    my $backup_name = $backup->{name}; 

    if(not $backup->{enabled})
    {
      _log("---------- Skipping $backup_name Backup (disabled) [{logtime}] ----------");
      next;
    }

    _log("---------- Started $backup_name Backup [{logtime}] ----------");

    my $cmd = $BACKUP_COMMAND;
    if(defined $config->{server}->{local})
    {
        $cmd =~ s/{REMOTE_BACKUP_USER}\@{REMOTE_BACKUP_SERVER}://i
    }
    $cmd =~ s/{LOCAL_BACKUP_FILES}/$backup->{location}/i;
    $cmd =~ s/{EXCLUDE_FILES}/$EXCLUDE_LOCATION\/$backup->{exclude_file}/i;
    $cmd =~ s/{REMOTE_BACKUP_USER}/$config->{server}->{user}/i;
    $cmd =~ s/{REMOTE_BACKUP_SERVER}/$config->{server}->{host}/i;
    $cmd =~ s/{REMOTE_BACKUP_LOCATION}/$config->{server}->{backup_location}/i;
    
    if(defined $backup->{cmd_before})
    {
      my $tmp = $SCRIPTS_DIR.$backup->{cmd_before};
      #my $tmp_output = `$tmp 2>&1`;
      my ($stdout, $stderr) = capture { system($tmp) };
      if($stderr ne "")
      {
         # Email but ATM print error
         $emailErrors .= "Cmd Before Error:\n".$stderr."\n\n";
      }
      _log($stdout);
    }
 
    my $output = `$cmd 2>&1`;
     my ($stdout, $stderr) = capture { system($cmd) };
     if($stderr ne "")
     {
        # Email but ATM print error
        $emailErrors .= "Error:\n".$stderr."\n\n";
	      print $emailErrors ."\n----------------\n";
     }
    _log($stdout);
    _log("---------- Finished $backup_name Backup [{logtime}] ----------");    
  }
}


sub _log{
  my $text = shift;
  my $logtime = strftime "%Y-%m-%d %H:%M:00", localtime;
  open(LOG, ">>$LOG");
  $text =~ s/{logtime}/$logtime/;
  print LOG $text."\n";
  close(LOG);
}
