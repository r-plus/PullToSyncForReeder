#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#define REFRESH_HEADER_HEIGHT 48.0f   //52.0f
#define TEXT_PULL @"Pull down to sync"
#define TEXT_RELEASE @"Release to sync"
#define TEXT_SYNCING @"Syncing"
				
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
  BOOL isDragging;
  BOOL isLoading;

- (void)viewDidLoad {
	%orig;
	[self addPullToRefreshHeader];
}

%new(v@:)
- (void)addPullToRefreshHeader {
	refreshHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0, 0 - REFRESH_HEADER_HEIGHT, 320, REFRESH_HEADER_HEIGHT)];
	refreshHeaderView.backgroundColor = [UIColor clearColor];
	
	refreshLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, REFRESH_HEADER_HEIGHT / 4 - 5, 320, REFRESH_HEADER_HEIGHT / 2)];
	refreshLabel.backgroundColor = [UIColor clearColor];
	refreshLabel.font = [UIFont boldSystemFontOfSize:15.0];
	refreshLabel.textColor = [UIColor colorWithRed:0.149 green:0.149 blue:0.149 alpha:1.0];
	refreshLabel.textAlignment = UITextAlignmentCenter;
	
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
		else if (scrollView.contentOffset.y >= -REFRESH_HEADER_HEIGHT)
		self.tableView.contentInset = UIEdgeInsetsMake(-scrollView.contentOffset.y, 0, 0, 0);
	} else if (isDragging && scrollView.contentOffset.y < 0) {
		[UIView beginAnimations:nil context:NULL];
		if (scrollView.contentOffset.y < -REFRESH_HEADER_HEIGHT) {
			refreshLabel.text = TEXT_RELEASE;
			[refreshArrow layer].transform = CATransform3DMakeRotation(M_PI * 2, 0, 0, 1);
		} else {
			refreshLabel.text = TEXT_PULL;
			[refreshArrow layer].transform = CATransform3DMakeRotation(M_PI, 0, 0, 1);
		}
		[UIView commitAnimations];
	}
}

%new(v@:)
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
	if (isLoading) return;
	isDragging = NO;
	if (scrollView.contentOffset.y <= -REFRESH_HEADER_HEIGHT) {
		[self startLoading];
	}
}

%new(v@:)
- (void)startLoading {
	isLoading = YES;
	
	// Show the header
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:0.3];
	self.tableView.contentInset = UIEdgeInsetsMake(REFRESH_HEADER_HEIGHT, 0, 0, 0);
	refreshLabel.text = TEXT_SYNCING;
	refreshArrow.hidden = YES;
	[refreshSpinner startAnimating];
	[UIView commitAnimations];
	
	// Refresh action!
	[self refresh];
}

%new(v@:)
- (void)stopLoading {
	isLoading = NO;
	
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
	[self sync:self];
	[self performSelector:@selector(stopLoading) withObject:nil afterDelay:1.0];
}

- (void)dealloc {
	[refreshHeaderView release];
	[refreshLabel release];
	[refreshArrow release];
	[refreshSpinner release];
	%orig;
}

%end
