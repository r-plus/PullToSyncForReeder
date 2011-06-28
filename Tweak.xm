#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <AudioToolbox/AudioServices.h>

#define REFRESH_HEADER_HEIGHT 48.0f   //52.0f
#define TEXT_PULL_ROOT @"Pull down to Sync"
#define TEXT_RELEASE_ROOT @"Release to Sync"
#define TEXT_SYNCING @"Syncing"
#define TEXT_PULL_READ @"Pull up to Mark All as Read"
#define TEXT_RELEASE_READ @"Release to Mark All as Read"

static float ReadArrowThreshold = 65.0f;
static float SyncArrowThreshold = 65.0f;
static NSString *TEXT_PULL;
static NSString *TEXT_RELEASE;
static int headerFunction = 0;
static BOOL soundEnable = NO;
static BOOL isDragging = NO;
static BOOL isLoading = NO;
static BOOL ReadEnable = YES;
static BOOL isSoundEnabledByPlist = YES;
static SystemSoundID psst1SoundId;
static SystemSoundID psst2SoundId;
static SystemSoundID popSoundId;
static UIView *footerView;
static UILabel *footerLabel;
static UIImageView *footerArrow;
static UIView *refreshHeaderView;
static UILabel *refreshLabel;
static UIImageView *refreshArrow;
static UIActivityIndicatorView *refreshSpinner;
static UIView *refreshHeaderView2;
static UILabel *refreshLabel2;
static UIImageView *refreshArrow2;
static UIActivityIndicatorView *refreshSpinner2;

__attribute__((visibility("hidden")))
@interface FeedListController : UITableViewController { //RealSuperClass:TableViewController
}
- (void)addPullToSyncHeader;
- (void)startLoading;
- (void)stopLoading;
- (void)refresh;
- (id)sync:(id)sync;
@end

__attribute__((visibility("hidden")))
@interface ItemsController : UITableViewController {  //RealSuperClass:TableViewController
}
- (void)addPullToSyncHeader;
- (void)addPullToReadFooter;
- (void)markAllAsReadAndPlaySound;
- (id)markAllRead:(id)read;
@end

__attribute__((visibility("hidden")))
@interface FeedController : UITableViewController{ //RealSuperClass:TableViewController
}
- (void)addPullToSyncHeader;
- (void)addPullToReadFooter;
- (void)markAllAsReadAndPlaySound;
- (id)markAllRead:(id)read;
@end


@implementation UITableViewController (PullToSyncForReeder)

- (void)addPullToSyncHeader {
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

- (void)addPullToReadFooter {	
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

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
	if (isLoading) return;
	isDragging = YES;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {

	//Sync part
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
			if (!soundEnable && isSoundEnabledByPlist) {
				AudioServicesPlaySystemSound(psst1SoundId);
				soundEnable = YES;
			}
		} else {
			refreshLabel.text = TEXT_PULL;
			[refreshArrow layer].transform = CATransform3DMakeRotation(M_PI, 0, 0, 1);
			if (soundEnable && isSoundEnabledByPlist) {
				AudioServicesPlaySystemSound(popSoundId);
				soundEnable = NO;
			}
		}
		[UIView commitAnimations];
	}
	
	//Read part
	if (!ReadEnable) return;

	double tableTail = self.tableView.bounds.origin.y + self.tableView.bounds.size.height;
	double triggerTail = footerView.frame.origin.y + footerView.frame.size.height;
	
	if (isDragging && scrollView.contentOffset.y > 0) {
		[UIView beginAnimations:nil context:NULL];
		
		if (triggerTail < 367) {
			if (scrollView.contentOffset.y > ReadArrowThreshold) {
				footerLabel.text = TEXT_RELEASE_READ;
				[footerArrow layer].transform = CATransform3DMakeRotation(M_PI, 0, 0, 1);
				if (!soundEnable && isSoundEnabledByPlist) {
					AudioServicesPlaySystemSound(psst1SoundId);
					soundEnable = YES;
				}
			} else {
				footerLabel.text = TEXT_PULL_READ;
				[footerArrow layer].transform = CATransform3DMakeRotation(M_PI * 2, 0, 0, 1);
				if (soundEnable && isSoundEnabledByPlist) {
					AudioServicesPlaySystemSound(popSoundId);
					soundEnable = NO;
				}
			}
		} else {
			if (tableTail > triggerTail + ReadArrowThreshold) {
				footerLabel.text = TEXT_RELEASE_READ;
				[footerArrow layer].transform = CATransform3DMakeRotation(M_PI, 0, 0, 1);
				if (!soundEnable && isSoundEnabledByPlist) {
					AudioServicesPlaySystemSound(psst1SoundId);
					soundEnable = YES;
				}
			} else {
				footerLabel.text = TEXT_PULL_READ;
				[footerArrow layer].transform = CATransform3DMakeRotation(M_PI * 2, 0, 0, 1);
				if (soundEnable && isSoundEnabledByPlist) {
					AudioServicesPlaySystemSound(popSoundId);
					soundEnable = NO;
				}
			}
		}
		[UIView commitAnimations];
	}
}

- (void)markAllAsReadAndPlaySound {
	if (isSoundEnabledByPlist)
		AudioServicesPlaySystemSound(psst2SoundId);
	self.tableView.contentInset = UIEdgeInsetsZero;
	[footerArrow layer].transform = CATransform3DMakeRotation(M_PI * 2, 0, 0, 1);
	soundEnable = NO;
}

- (void)refresh {
	soundEnable = NO;
	if (isSoundEnabledByPlist)
		AudioServicesPlaySystemSound(psst2SoundId);
	[self performSelector:@selector(stopLoading) withObject:nil afterDelay:1.0];
}

- (void)startLoading {
	if (headerFunction != 0) {
		if (isSoundEnabledByPlist)
			AudioServicesPlaySystemSound(psst2SoundId);
		self.tableView.contentInset = UIEdgeInsetsZero;
		[refreshArrow layer].transform = CATransform3DMakeRotation(M_PI, 0, 0, 1);
		soundEnable = NO;
		
		if (headerFunction == 1)
			[self.navigationController popViewControllerAnimated:YES];
		
	} else {
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
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {

	//Sync part
	if (isLoading) return;
	isDragging = NO;
	if (scrollView.contentOffset.y <= -SyncArrowThreshold) {
		[self startLoading];
	}
	
	//Read part
	if (!ReadEnable) return;
	
	double tableTail = self.tableView.bounds.origin.y + self.tableView.bounds.size.height;
	double triggerTail = footerView.frame.origin.y + footerView.frame.size.height;
	
	isDragging = NO;
	if (triggerTail == footerView.frame.size.height) return;
	
	if (triggerTail < 367) {
		if (scrollView.contentOffset.y > ReadArrowThreshold) {
			[self markAllAsReadAndPlaySound];
		}
	} else {
		if (tableTail > triggerTail + ReadArrowThreshold ) {
			[self markAllAsReadAndPlaySound];
		}
	}
}

- (void)stopLoading {
	isLoading = NO;
	if (isSoundEnabledByPlist)
		AudioServicesPlaySystemSound(popSoundId);
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDelegate:self];
	[UIView setAnimationDuration:0.3];
	[UIView setAnimationDidStopSelector:@selector(stopLoadingComplete:finished:context:)];
	self.tableView.contentInset = UIEdgeInsetsZero;
	[refreshArrow layer].transform = CATransform3DMakeRotation(M_PI, 0, 0, 1);
	[UIView commitAnimations];
}

- (void)stopLoadingComplete:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context {
	refreshLabel.text = TEXT_PULL;
	refreshArrow.hidden = NO;
	[refreshSpinner stopAnimating];
}

@end

%hook FeedController //FeedView

- (void)viewDidLoad {
	%orig;
	[self addPullToReadFooter];
	[self addPullToSyncHeader];
}

- (void)markAllAsReadAndPlaySound {
	%orig;
	[self markAllRead:self];
}

- (void)startLoading {
	%orig;
	if (headerFunction == 2)
		[self markAllRead:self];
}

- (void)refresh {
	id tmp = [[objc_getClass("FeedListController") alloc] init];
	[tmp sync:self];
	[tmp release];
	%orig;
}

%end

%hook ItemsController //DirectoryView

- (void)viewDidLoad {
	%orig;
	[self addPullToReadFooter];
	[self addPullToSyncHeader];
}

- (void)markAllAsReadAndPlaySound {
	%orig;
	[self markAllRead:self];
}

- (void)startLoading {
	%orig;
	if (headerFunction == 2)
		[self markAllRead:self];
}

- (void)refresh {
	id tmp = [[objc_getClass("FeedListController") alloc] init];
	[tmp sync:self];
	[tmp release];
	%orig;
}

%end

%hook FeedListController //RootView

- (void)addPullToSyncHeader {
	//override for add suffix "2".
	
	refreshHeaderView2 = [[UIView alloc] initWithFrame:CGRectMake(0, 0 - REFRESH_HEADER_HEIGHT, 320, REFRESH_HEADER_HEIGHT)];
	refreshHeaderView2.backgroundColor = [UIColor clearColor];
	refreshHeaderView2.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	
	refreshLabel2 = [[UILabel alloc] initWithFrame:CGRectMake(0, REFRESH_HEADER_HEIGHT / 4 - 5, 320, REFRESH_HEADER_HEIGHT / 2)];
	refreshLabel2.backgroundColor = [UIColor clearColor];
	refreshLabel2.font = [UIFont boldSystemFontOfSize:15.0];
	refreshLabel2.textColor = [UIColor colorWithRed:0.149 green:0.149 blue:0.149 alpha:1.0];
	refreshLabel2.textAlignment = UITextAlignmentCenter;
	refreshLabel2.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	
	refreshArrow2 = [[[UIImageView alloc] init] initWithImage:[UIImage imageNamed:@"PullArrow.png"]];
	//refreshArrow.image = [[UIImage alloc] initWithContentsOfFile:@"/Library/PullToSyncForReeder/whiteArrow@2x.png"];
	refreshArrow2.frame = CGRectMake((REFRESH_HEADER_HEIGHT - 27) / 2 + 20,
																	(REFRESH_HEADER_HEIGHT - 44) / 2,
																	21, 39);
	
	refreshSpinner2 = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
	refreshSpinner2.frame = CGRectMake(30, 11, 20, 20);
	refreshSpinner2.hidesWhenStopped = YES;

	[refreshHeaderView2 addSubview:refreshLabel2];
	[refreshHeaderView2 addSubview:refreshArrow2];
	[refreshHeaderView2 addSubview:refreshSpinner2];
	[self.tableView addSubview:refreshHeaderView2];
}

- (void)viewDidLoad {
	%orig;
	[self addPullToSyncHeader];
}

- (void)refresh {
	[self sync:self];
	%orig;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	//Sync part only. override for remove Read part and add suffix "2".

	if (isLoading) {
		if (scrollView.contentOffset.y > 0)
			self.tableView.contentInset = UIEdgeInsetsZero;
		else if (scrollView.contentOffset.y >= -SyncArrowThreshold)
			self.tableView.contentInset = UIEdgeInsetsMake(-scrollView.contentOffset.y, 0, 0, 0);
	} else if (isDragging && scrollView.contentOffset.y < 0) {
		[UIView beginAnimations:nil context:NULL];
		if (scrollView.contentOffset.y < -SyncArrowThreshold) {
			refreshLabel2.text = TEXT_RELEASE_ROOT;
			[refreshArrow2 layer].transform = CATransform3DMakeRotation(M_PI * 2, 0, 0, 1);
			if (!soundEnable && isSoundEnabledByPlist) {
				AudioServicesPlaySystemSound(psst1SoundId);
				soundEnable = YES;
			}
		} else {
			refreshLabel2.text = TEXT_PULL_ROOT;
			[refreshArrow2 layer].transform = CATransform3DMakeRotation(M_PI, 0, 0, 1);
			if (soundEnable && isSoundEnabledByPlist) {
				AudioServicesPlaySystemSound(popSoundId);
				soundEnable = NO;
			}
		}
		[UIView commitAnimations];
	}
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
	//Sync part only. override for remove Read part.

	if (isLoading) return;
	isDragging = NO;
	if (scrollView.contentOffset.y <= -SyncArrowThreshold) {
		[self startLoading];
	}
}

- (void)startLoading {
	//override for add suffix "2".

	isLoading = YES;
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:0.3];
	self.tableView.contentInset = UIEdgeInsetsMake(SyncArrowThreshold, 0, 0, 0);
	refreshLabel2.text = TEXT_SYNCING;
	refreshArrow2.hidden = YES;
	[refreshSpinner2 startAnimating];
	[UIView commitAnimations];
	
	[self refresh];
}

- (void)stopLoadingComplete:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context {
	//override for add suffix "2".
	refreshLabel2.text = TEXT_PULL_ROOT;
	refreshArrow2.hidden = NO;
	[refreshSpinner2 stopAnimating];
}

%end


///////////////////////
//          Common Part
///////////////////////

//#import <UIKit/UIKit.h>
//#import <AudioToolbox/AudioServices.h>

static void LoadSettings(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	NSDictionary *dict = [[NSDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/jp.r-plus.PullToSyncForReeder.plist"];
	SyncArrowThreshold = [[dict objectForKey:@"SyncArrowThreshold"] floatValue];
	if(!SyncArrowThreshold) SyncArrowThreshold = 65.0f;
	ReadArrowThreshold = [[dict objectForKey:@"ReadArrowThreshold"] floatValue];
	if(!ReadArrowThreshold) ReadArrowThreshold = 65.0f;
	headerFunction = [[dict objectForKey:@"HeaderFunction"] intValue];
	if(!headerFunction) headerFunction = 0;
	if([dict objectForKey:@"ReadEnabled"] != nil) ReadEnable = [[dict objectForKey:@"ReadEnabled"] boolValue];
	if([dict objectForKey:@"SoundEnabled"] != nil) isSoundEnabledByPlist = [[dict objectForKey:@"SoundEnabled"] boolValue];

	if (headerFunction == 1) {
		TEXT_PULL = @"Pull down to Prev View";
		TEXT_RELEASE = @"Release to Prev View";
	} else if (headerFunction == 2) {
		TEXT_PULL = @"Pull down to Mark All as Read";
		TEXT_RELEASE = @"Release to Mark All as Read";
	} else {
		TEXT_PULL = @"Pull down to Sync";
		TEXT_RELEASE = @"Release to Sync";
	}
	[dict release];
}
	
__attribute__((constructor)) 
static void PullToSyncForReeder_initializer() 
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	// Reeder only!
	if (![[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"ch.reeder"])
		return;
	isSoundEnabledByPlist = YES;
	soundEnable = NO;
	isDragging = NO;
	headerFunction = 0;
	NSURL *psst1WavURL = [NSURL fileURLWithPath:@"/Library/PullToSyncForReeder/psst1.wav"];
	NSURL *psst2WavURL = [NSURL fileURLWithPath:@"/Library/PullToSyncForReeder/psst2.wav"];
	NSURL *popWavURL = [NSURL fileURLWithPath:@"/Library/PullToSyncForReeder/pop.wav"];
	AudioServicesCreateSystemSoundID((CFURLRef)psst1WavURL, &psst1SoundId);
	AudioServicesCreateSystemSoundID((CFURLRef)psst2WavURL, &psst2SoundId);
	AudioServicesCreateSystemSoundID((CFURLRef)popWavURL, &popSoundId);
	
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, LoadSettings, CFSTR("jp.r-plus.PullToSyncForReeder.settingschanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
	LoadSettings(nil,nil,nil,nil,nil);
	[pool release];	
}

__attribute__((destructor)) 
static void PullToSyncForReeder_destructor() 
{
	[refreshHeaderView release];
	[refreshLabel release];
	[refreshArrow release];
	[refreshSpinner release];
	[refreshHeaderView2 release];
	[refreshLabel2 release];
	[refreshArrow2 release];
	[refreshSpinner2 release];
	[footerView release];
	[footerLabel release];
	[footerArrow release];
	AudioServicesDisposeSystemSoundID(psst1SoundId);
	AudioServicesDisposeSystemSoundID(psst2SoundId);
	AudioServicesDisposeSystemSoundID(popSoundId);
}
