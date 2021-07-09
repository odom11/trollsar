//
// Created by ich on 11/1/21.
//

#include <iostream>
#include <view/initializeOptix.h>
int simpleAdd(int a, int b);

int main(int iargc, char *argv[]) {
    initializeOptix();
    int foo = simpleAdd(2, 3);
    std::cout << foo << std::endl;
}
