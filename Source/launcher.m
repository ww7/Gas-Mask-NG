/***************************************************************************
 *   Copyright (C) 2009-2010 by Clockwise   *
 *   copyright@clockwise.ee   *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.,                                       *
 *   59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             *
 ***************************************************************************/


int main(int argc, char *argv[])
{
	NSString *path = [[NSBundle mainBundle] bundlePath];
	path = [path stringByDeletingLastPathComponent];
	path = [path stringByDeletingLastPathComponent];
	path = [path stringByDeletingLastPathComponent];
	
    // Pass the application path as an argument, never interpolate it into a
    // shell command: installation paths can legitimately contain apostrophes.
    [NSThread sleepForTimeInterval:1];
    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/open"];
    task.arguments = @[path, @"--args", @"openatlogin"];
    [task launchAndReturnError:nil];

	return 0;
}