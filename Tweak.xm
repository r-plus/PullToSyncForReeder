///////////////////////
//      Sync Arrow Part
///////////////////////
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <AudioToolbox/AudioServices.h>

#define REFRESH_HEADER_HEIGHT 48.0f   //52.0f
#define TEXT_PULL @"Pull down to sync"
#define TEXT_RELEASE @"Release to sync"
#define TEXT_SYNCING @"Syncing"

static float ReadArrowThreshold = 65.0f;
static float SyncArrowThreshold = 65.0f;
static BOOL soundEnable = NO;
static BOOL isDragging = NO;
static BOOL ReadEnable = YES;
static SystemSoundID psst1SoundId;
static SystemSoundID psst2SoundId;
static SystemSoundID popSoundId;

__attribute__((visibility("hidden")))
@interface FeedListController : UITableViewController {
}
- (void)addPullToRefreshHeader;
- (void)startLoading;
- (void)stopLoading;
- (void)refresh;
- (id)sync:(id)sync;
@end


%hook FeedListController

  UIView *refreshHeaderView;
  UILabel *refreshLabel;
  UIImageView *refreshArrow;
  UIActivityIndicatorView *refreshSpinner;
  BOOL isLoading;

- (void)viewDidLoad {
	%orig;
	[self addPullToRefreshHeader];
}

%new(v@:)
- (void)addPullToRefreshHeader {
	refreshHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0, 0 - REFRESH_HEADER_HEIGHT, 320, REFRESH_HEADER_HEIGHT)];
	refreshHeaderView.backgroundColor = [UIColor clearColor];
	refreshHeaderView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	
	refreshLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, REFRESH_HEADER_HEIGHT / 4 - 5, 320, REFRESH_HEADER_HEIGHT / 2)];
	refreshLabel.backgroundColor = [UIColor clearColor];
	refreshLabel.font = [UIFont boldSystemFontOfSize:15.0];
	refreshLabel.textColor = [UIColor colorWithRed:0.149 green:0.149 blue:0.149 alpha:1.0];
	refreshLabel.textAlignment = UITextAlignmentCenter;
	refreshLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	
	refreshArrow = [[[UIImageView alloc] init] initWithImage:[UIImage imageNamed:@"PullArrow.png"]];
	//refreshArrow.image = [[UIImage alloc] initWithContentsOfFile:@"/Library/PullToSyncForReeder/whiteArrow@2x.png"];
	refreshArrow.frame = CGRectMake((REFRESH_HEADER_HEIGHT - 27) / 2 + 20,
																	(REFRESH_HEADER_HEIGHT - 44) / 2,
																	21, 39);
	
	refreshSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
	refreshSpinner.frame = CGRectMake(30, 11, 20, 20);
	refreshSpinner.hidesWhenStopped = YES;
	
	[refreshHeaderView addSubview:refreshLabel];
	[refreshHeaderView addSubview:refreshArrow];
	[refreshHeaderView addSubview:refreshSpinner];
	[self.tableView addSubview:refreshHeaderView];
}

%new(v@:)
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
	if (isLoading) return;
	isDragging = YES;
}

%new(v@:)
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	if (isLoading) {
		if (scrollView.contentOffset.y > 0)
		self.tableView.contentInset = UIEdgeInsetsZero;
		else if (scrollView.contentOffset.y >= -SyncArrowThreshold)
		self.tableView.contentInset = UIEdgeInsetsMake(-scrollView.contentOffset.y, 0, 0, 0);
	} else if (isDragging && scrollView.contentOffset.y < 0) {
		[UIView beginAnimations:nil context:NULL];
		if (scrollView.contentOffset.y < -SyncArrowThreshold) {
			refreshLabel.text = TEXT_RELEASE;
			[refreshArrow layer].transform = CATransform3DMakeRotation(M_PI * 2, 0, 0, 1);
			if (!soundEnable) {
				AudioServicesPlaySystemSound(psst1SoundId);
				soundEnable = YES;
			}
		} else {
			refreshLabel.text = TEXT_PULL;
			[refreshArrow layer].transform = CATransform3DMakeRotation(M_PI, 0, 0, 1);
			if (soundEnable) {
				AudioServicesPlaySystemSound(popSoundId);
				soundEnable = NO;
			}
		}
		[UIView commitAnimations];
	}
}

%new(v@:)
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
	if (isLoading) return;
	isDragging = NO;
	if (scrollView.contentOffset.y <= -SyncArrowThreshold) {
		[self startLoading];
	}
}

%new(v@:)
- (void)startLoading {
	isLoading = YES;
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:0.3];
	self.tableView.contentInset = UIEdgeInsetsMake(SyncArrowThreshold, 0, 0, 0);
	refreshLabel.text = TEXT_SYNCING;
	refreshArrow.hidden = YES;
	[refreshSpinner startAnimating];
	[UIView commitAnimations];
	
	[self refresh];
}

%new(v@:)
- (void)stopLoading {
	isLoading = NO;
	AudioServicesPlaySystemSound(popSoundId);
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDelegate:self];
	[UIView setAnimationDuration:0.3];
	[UIView setAnimationDidStopSelector:@selector(stopLoadingComplete:finished:context:)];
	self.tableView.contentInset = UIEdgeInsetsZero;
	[refreshArrow layer].transform = CATransform3DMakeRotation(M_PI, 0, 0, 1);
	[UIView commitAnimations];
}

%new(v@:)
- (void)stopLoadingComplete:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context {
	refreshLabel.text = TEXT_PULL;
	refreshArrow.hidden = NO;
	[refreshSpinner stopAnimating];
}

%new(v@:)
- (void)refresh {
	soundEnable = NO;
	AudioServicesPlaySystemSound(psst2SoundId);
	[self sync:self];
	[self performSelector:@selector(stopLoading) withObject:nil afterDelay:1.0];
}

- (void)dealloc {
	[refreshHeaderView release];
	[refreshLabel release];
	[refreshArrow release];
	[refreshSpinner release];
	AudioServicesDisposeSystemSoundID(psst1SoundId);
	AudioServicesDisposeSystemSoundID(psst2SoundId);
	AudioServicesDisposeSystemSoundID(popSoundId);
	%orig;
}

%end


///////////////////////
//          Common Part
///////////////////////

//#import <UIKit/UIKit.h>
//#import <AudioToolbox/AudioServices.h>

static void LoadSettings(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	NSDictionary *dict = [[NSDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/jp.r-plus.PullFeatureForReeder.plist"];
	SyncArrowThreshold = [[dict objectForKey:@"SyncArrowThreshold"] floatValue];
	if(!SyncArrowThreshold) SyncArrowThreshold = 65.0f;
	ReadArrowThreshold = [[dict objectForKey:@"ReadArrowThreshold"] floatValue];
	if(!ReadArrowThreshold) ReadArrowThreshold = 65.0f;
	if([dict objectForKey:@"ReadEnabled"] != nil) ReadEnable = [[dict objectForKey:@"ReadEnabled"] boolValue];

	[dict release];
}
	
__attribute__((constructor)) 
static void PullFeatureForReeder_initializer() 
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	soundEnable = NO;
	isDragging = NO;
	NSURL *psst1WavURL = [NSURL fileURLWithPath:@"/Library/PullFeatureForReeder/psst1.wav"];
	NSURL *psst2WavURL = [NSURL fileURLWithPath:@"/Library/PullFeatureForReeder/psst2.wav"];
	NSURL *popWavURL = [NSURL fileURLWithPath:@"/Library/PullFeatureForReeder/pop.wav"];
	AudioServicesCreateSystemSoundID((CFURLRef)psst1WavURL, &psst1SoundId);
	AudioServicesCreateSystemSoundID((CFURLRef)psst2WavURL, &psst2SoundId);
	AudioServicesCreateSystemSoundID((CFURLRef)popWavURL, &popSoundId);
	
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, LoadSettings, CFSTR("jp.r-plus.PullFeatureForReeder.settingschanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
	LoadSettings(nil,nil,nil,nil,nil);
	[pool release];
	
}



///////////////////////
//      Read Arrow Part
///////////////////////


//#import <UIKit/UIKit.h>
//#import <QuartzCore/QuartzCore.h>
//#import <AudioToolbox/AudioServices.h>

//#define REFRESH_HEADER_HEIGHT 48.0f   //52.0f
#define TEXT_PULL_READ @"Pull up to Mark All as Read"
#define TEXT_RELEASE_READ @"Release to Mark All as Read"

__attribute__((visibility("hidden")))
@interface ItemsController : UITableViewController {
}
- (void)addPullToRefreshHeader;
- (id)markAllRead:(id)read;
@end

%hook ItemsController

  UIView *footerView;
  UILabel *footerLabel;
  UIImageView *footerArrow;

- (void)viewDidLoad {
	%orig;
	[self addPullToRefreshHeader];
}

%new(v@:)
- (void)addPullToRefreshHeader {	
	footerView = [[UIView alloc] initWithFrame:CGRectMake(0, REFRESH_HEADER_HEIGHT, self.tableView.bounds.size.width, REFRESH_HEADER_HEIGHT)];
	footerView.backgroundColor = [UIColor clearColor];
	
	footerLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, REFRESH_HEADER_HEIGHT / 4 - 5, self.tableView.bounds.size.width, REFRESH_HEADER_HEIGHT / 2)];
	footerLabel.backgroundColor = [UIColor clearColor];
	footerLabel.font = [UIFont boldSystemFontOfSize:15.0];
	footerLabel.textColor = [UIColor colorWithRed:0.149 green:0.149 blue:0.149 alpha:1.0];
	footerLabel.textAlignment = UITextAlignmentCenter;
	footerLabel.text = TEXT_PULL_READ;
	
	footerArrow = [[[UIImageView alloc] init] initWithImage:[UIImage imageNamed:@"PullArrow.png"]];
	//footerArrow.image = [[UIImage alloc] initWithContentsOfFile:@"/Library/PullToSyncForReeder/whiteArrow@2x.png"];
	footerArrow.frame = CGRectMake((REFRESH_HEADER_HEIGHT - 27) / 2 + 20,
																	(REFRESH_HEADER_HEIGHT - 44) / 2,
																	21, 39);

	if (!ReadEnable) return;

	[footerView addSubview:footerLabel];
	[footerView addSubview:footerArrow];
	self.tableView.tableFooterView = footerView;
}

%new(v@:)
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
	isDragging = YES;
}


%new(v@:)
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	if (!ReadEnable) return;

	double tableTail = self.tableView.bounds.origin.y + self.tableView.bounds.size.height;
	double triggerTail = footerView.frame.origin.y + footerView.frame.size.height;
	
	if (isDragging) {
		[UIView beginAnimations:nil context:NULL];
		
		if (triggerTail < 367) {
			if (scrollView.contentOffset.y > ReadArrowThreshold) {
				footerLabel.text = TEXT_RELEASE_READ;
				[footerArrow layer].transform = CATransform3DMakeRotation(M_PI, 0, 0, 1);
				if (!soundEnable) {
					AudioServicesPlaySystemSound(psst1SoundId);
					soundEnable = YES;
				}
			} else {
				footerLabel.text = TEXT_PULL_READ;
				[footerArrow layer].transform = CATransform3DMakeRotation(M_PI * 2, 0, 0, 1);
				if (soundEnable) {
					AudioServicesPlaySystemSound(popSoundId);
					soundEnable = NO;
				}
			}
		} else {
			if (tableTail > triggerTail + ReadArrowThreshold) {
				footerLabel.text = TEXT_RELEASE_READ;
				[footerArrow layer].transform = CATransform3DMakeRotation(M_PI, 0, 0, 1);
				if (!soundEnable) {
					AudioServicesPlaySystemSound(psst1SoundId);
					soundEnable = YES;
				}
			} else {
				footerLabel.text = TEXT_PULL_READ;
				[footerArrow layer].transform = CATransform3DMakeRotation(M_PI * 2, 0, 0, 1);
				if (soundEnable) {
					AudioServicesPlaySystemSound(popSoundId);
					soundEnable = NO;
				}
			}
		}
		[UIView commitAnimations];
	}
}


%new(v@:)
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
	if (!ReadEnable) return;
	
	double tableTail = self.tableView.bounds.origin.y + self.tableView.bounds.size.height;
	double triggerTail = footerView.frame.origin.y + footerView.frame.size.height;
	
	isDragging = NO;
	if (triggerTail == footerView.frame.size.height) return;
	
	if (triggerTail < 367) {
		if (scrollView.contentOffset.y > ReadArrowThreshold) {
			AudioServicesPlaySystemSound(psst2SoundId);
			[self markAllRead:self];
			self.tableView.contentInset = UIEdgeInsetsZero;
			[footerArrow layer].transform = CATransform3DMakeRotation(M_PI * 2, 0, 0, 1);
			soundEnable = NO;
		}
	} else {
		if (tableTail > triggerTail + ReadArrowThreshold ) {
			AudioServicesPlaySystemSound(psst2SoundId);
			[self markAllRead:self];
			self.tableView.contentInset = UIEdgeInsetsZero;
			[footerArrow layer].transform = CATransform3DMakeRotation(M_PI * 2, 0, 0, 1);
			soundEnable = NO;
		}
	}
}

- (void)dealloc {
	[footerView release];
	[footerLabel release];
	[footerArrow release];
	%orig;
}

%end

