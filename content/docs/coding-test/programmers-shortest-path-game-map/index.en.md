---
title: Programmers / Shortest Path in Game Map
---

## Problem

* Link
  * [https://programmers.co.kr/learn/courses/30/lessons/1844](https://programmers.co.kr/learn/courses/30/lessons/1844)
* Description
  * Find the shortest path in a game map
* Type
  * Brute Force / BFS

## Solution 1

```java {caption="Solution 1", linenos=table}
import java.util.LinkedList;

class Solution {
    public int solution(int[][] maps) {
        // Get map size
        int mapX = maps.length;
        int mapY = maps[0].length;
        System.out.printf("mapX:%d, mapY:%d", mapX, mapY);
        
        // Init vars
    	  boolean[][] visitedMap = new boolean[mapX][mapY];
        LinkedList<Position> nextQueue = new LinkedList<>();
        
        // Find path
        visitedMap[0][0] = true;
        nextQueue.offer(new Position(0, 0, 1));
        while(nextQueue.size() != 0) {
            // Get next position
            Position nextPos = nextQueue.poll();
            int nextX = nextPos.getX();
            int nextY = nextPos.getY();
            int nextDepth = nextPos.getDepth();
            
            // Check this position is goal
           	if (nextX == mapX - 1 && nextY == mapY - 1) {
                return nextDepth;
            }
            
            // Enqueue next position to visit
            if ((nextX+1 < mapX) && (maps[nextX+1][nextY] == 1) && (!visitedMap[nextX+1][nextY])){
                visitedMap[nextX+1][nextY] = true;
                nextQueue.offer(new Position(nextX+1, nextY, nextDepth+1));
            } 
            if ((nextY+1 < mapY) && (maps[nextX][nextY+1] == 1) && (!visitedMap[nextX][nextY+1])){
                visitedMap[nextX][nextY+1] = true;
                nextQueue.offer(new Position(nextX, nextY+1, nextDepth+1));
            } 
            if ((nextX-1 >= 0) && (maps[nextX-1][nextY] == 1) && (!visitedMap[nextX-1][nextY])){
                visitedMap[nextX-1][nextY] = true;
                nextQueue.offer(new Position(nextX-1, nextY, nextDepth+1));
            } 
            if ((nextY-1 >= 0) && (maps[nextX][nextY-1] == 1) && (!visitedMap[nextX][nextY-1])){
                visitedMap[nextX][nextY-1] = true;
                nextQueue.offer(new Position(nextX, nextY-1, nextDepth+1));
            }
        }
        
        // Not reachable
        return -1;
    }
}

class Position {
    public int x;
    public int y;
    public int depth;
    
    public Position(int x, int y, int depth) {
        this.x = x;
        this.y = y;
        this.depth = depth;
    }
    
    public int getX() {
        return x;
    }
    
    public int getY() {
        return y;
    }
    
    public int getDepth() {
        return depth;
    }
}
```

* Description
  * Use BFS for search
  * While DFS can search all paths and then determine the shortest path, BFS doesn't need to search all paths
* Time Complexity
  * O(len(mapX) * len(mapY))
  * Proportional to map size as it visits each cell once while searching for the path
* Space Complexity
  * O(len(mapX) * len(mapY))
  * Memory usage proportional to map size for function input

